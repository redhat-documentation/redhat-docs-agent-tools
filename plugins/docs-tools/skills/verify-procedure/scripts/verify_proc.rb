require 'open3'
require 'yaml'
require 'tempfile'

# ProcedureVerifier: Validates AsciiDoc procedures as "guided exercises"
class ProcedureVerifier
  def initialize(file_path)
    @file_path = file_path
    @content = File.read(file_path)
    @results = []
  end

  def run_verification
    puts "--- Starting Procedure Validation: #{@file_path} ---"

    # 1. Check for Best Practices (Instructional Design)
    check_best_practices

    # 2. Extract and Process Blocks
    blocks = extract_code_blocks

    if blocks.empty?
      puts "[ERROR] No executable steps or source blocks found."
      return
    end

    blocks.each_with_index do |block, index|
      process_step(index + 1, block[:instruction], block[:type], block[:content], block[:is_example])
    end

    summarize
  end

  private

  def extract_code_blocks
    blocks = []
    lines = @content.lines
    i = 0
    current_step = nil

    while i < lines.length
      line = lines[i]

      # Match numbered steps (., .., ..., etc.) to track context
      if line =~ /^(\.+)\s+(.+)$/
        current_step = $2.strip
      end

      # Match source blocks with various formats:
      # [source,terminal], [source,bash], [source,yaml]
      # [source,terminal,subs="attributes+"], etc.
      if line =~ /^\[source,(terminal|bash|yaml|shell)(?:,.*?)?\]\s*$/
        source_type = $1

        # Check if this is an example output block (preceded by "Example output" or similar)
        is_example = false
        lookback = [i - 1, 0].max
        5.times do
          break if lookback < 0
          prev_line = lines[lookback].to_s.downcase
          if prev_line.include?("example output") || prev_line.include?("output is shown")
            is_example = true
            break
          end
          break if prev_line =~ /^(\.+)\s+/ # Stop at previous step
          lookback -= 1
        end

        # Find the opening ---- delimiter
        i += 1
        while i < lines.length && lines[i] !~ /^----\s*$/
          i += 1
        end

        # Extract content between ---- delimiters
        i += 1
        content_lines = []
        while i < lines.length && lines[i] !~ /^----\s*$/
          content_lines << lines[i]
          i += 1
        end

        content = content_lines.join.strip

        # Normalize terminal/shell to bash for execution
        type = (source_type == 'terminal' || source_type == 'shell') ? 'bash' : source_type

        # Only add non-empty blocks
        unless content.empty?
          blocks << {
            instruction: current_step || "Unknown step",
            type: type,
            content: content,
            is_example: is_example
          }
        end
      end

      i += 1
    end

    blocks
  end

  def check_best_practices
    # Ensure no "Magic Steps" - Identify assumed knowledge
    if @content.length > 500 && !@content.include?("oc login") && !@content.include?("export")
      puts "[ADVICE] Warning: No login or environment setup found. Check for 'magic steps'."
    end
  end

  def process_step(step_num, instruction, type, content, is_example)
    puts "\n[Step #{step_num}] #{instruction}"

    if is_example
      puts "[SKIP] Example output - not executed"
      return
    end

    # Check for placeholders that need user input
    if has_placeholders?(content)
      puts "[SKIP] Contains placeholders (e.g., <path_to_must_gather>) - requires user input"
      puts "Content preview: #{content[0..100]}..."
      return
    end

    case type
    when 'yaml'
      validate_yaml(content, step_num)
    when 'bash'
      execute_bash(content, step_num, instruction)
    end
  end

  def has_placeholders?(content)
    # Check for common placeholder patterns
    content.match?(/<[^>]+>/) || # Angle bracket placeholders like <path>
    content.match?(/\$\{[^}]+\}/) || # Variable placeholders like ${VAR}
    content.include?('CHANGEME') ||
    content.include?('REPLACE')
  end

  def validate_yaml(content, step_num)
    begin
      # Lint the YAML for syntax errors
      YAML.safe_load(content)
      puts "[VALID] YAML syntax for Step #{step_num} is correct."

      # If it looks like a MachineConfig or K8s Resource, check if it can be 'dry-run'
      if content.include?("apiVersion:")
        Tempfile.open(['resource', '.yaml']) do |f|
          f.write(content)
          f.close
          stdout, stderr, status = Open3.capture3("oc apply -f #{f.path} --dry-run=client")
          if status.success?
            puts "[VALID] Resource logic (dry-run) passed for Step #{step_num}."
          else
            puts "[FAILURE] Resource validation failed: #{stderr}"
          end
        end
      end
    rescue Psych::SyntaxError => e
      puts "[FAILURE] YAML Syntax error in Step #{step_num}: #{e.message}"
    end
  end

  def execute_bash(command, step_num, instruction)
    # Clean up command: remove $ prompt symbols from each line
    clean_command = command.lines.map { |line| line.sub(/^\$ /, '') }.join

    # Handle multi-line commands with backslash continuations
    if clean_command.include?('\\')
      # Join lines that end with backslash
      clean_command = clean_command.gsub(/\\\n\s*/, ' ').strip
    else
      clean_command = clean_command.strip
    end

    puts "Executing: #{clean_command[0..150]}#{clean_command.length > 150 ? '...' : ''}"

    stdout, stderr, status = Open3.capture3(clean_command)

    if status.success?
      puts "[SUCCESS] Step #{step_num} executed."

      # Show output if it's a verification/check command
      if instruction.downcase.match?(/verify|check|confirm|retrieve|identify/)
        puts "Output: #{stdout.strip[0..200]}" unless stdout.strip.empty?
        puts "-> Verification successfully performed."
      end

      @results << { step: step_num, status: :passed, output: stdout.strip }
    else
      puts "[FAILURE] Step #{step_num} failed."
      puts "STDERR: #{stderr.strip}" unless stderr.strip.empty?
      puts "STDOUT: #{stdout.strip}" unless stdout.strip.empty?
      @results << { step: step_num, status: :failed, error: stderr.strip }

      # Don't exit immediately - continue with warnings
      puts "[WARNING] Continuing with remaining steps despite failure..."
    end
  end

  def summarize
    puts "\n" + "="*60
    puts "FINAL SUMMARY"
    puts "="*60

    passed = @results.count { |r| r[:status] == :passed }
    failed = @results.count { |r| r[:status] == :failed }

    puts "Total executable steps: #{@results.size}"
    puts "Passed: #{passed}"
    puts "Failed: #{failed}"

    if failed > 0
      puts "\nFailed steps:"
      @results.select { |r| r[:status] == :failed }.each do |result|
        puts "  - Step #{result[:step]}: #{result[:error]&.split("\n")&.first}"
      end
    end

    # Check if a global verification example was included
    unless @content.downcase.include?("verify") || @content.downcase.include?(".verification")
      puts "\n[ADVICE] Consider adding an end-to-end verification step to this procedure."
    end

    puts "="*60
    puts passed == @results.size ? "✓ All steps PASSED" : "✗ Some steps FAILED"
    puts "="*60
  end
end

# Execution
if ARGV.empty?
  puts "Usage: ruby verify_procedure.rb <file.adoc>"
else
  ProcedureVerifier.new(ARGV[0]).run_verification
end
