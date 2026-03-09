#!/usr/bin/env ruby
# jtbd_gap_analysis.rb
# Extract procedure steps, verification quality, decision points, and
# destructive operations for JTBD gap analysis.
# Usage: ruby jtbd_gap_analysis.rb <file.adoc> [--json] [--dry-run]

require_relative '../../../lib/asciidoc_parser'

GAP_TYPES = [
  'Prerequisite verification gap',
  'Monitoring gap',
  'Outcome verification gap',
  'Error recovery gap',
  'Decision gap',
  'Rollback gap'
].freeze

def analyze_gaps(path)
  parsed = AsciidocParser.parse(path)
  content = parsed[:raw_content]
  lines = parsed[:lines]

  gaps = []

  # 1. Prerequisite verification gap
  if parsed[:has_prerequisites]
    prereq_has_commands = false
    in_prereqs = false
    lines.each do |line|
      if line =~ /^\.Prerequisites\s*$/i
        in_prereqs = true
        next
      end
      if in_prereqs
        break if line =~ /^\.(?!\.)[A-Z]/
        break if line =~ /^={2,}\s+/
        if line =~ /`[^`]+`/ || line =~ /\b(oc|kubectl|curl|verify|check|confirm|run|execute)\b.*command/i
          prereq_has_commands = true
        end
      end
    end

    unless prereq_has_commands
      gaps << {
        type: 'Prerequisite verification gap',
        severity: 'medium',
        description: 'Prerequisites listed without verification commands to confirm readiness',
        line: nil
      }
    end
  elsif parsed[:procedure_steps].any?
    # Procedure without prerequisites section
    gaps << {
      type: 'Prerequisite verification gap',
      severity: 'low',
      description: 'Procedure has no .Prerequisites section',
      line: nil
    }
  end

  # 2. Monitoring gap - procedures with no progress indication
  if parsed[:procedure_steps].length > 3
    has_monitoring = false
    parsed[:procedure_steps].each do |step|
      if step[:text] =~ /\b(wait|verify|check|confirm|monitor|watch|observe|poll|status)\b/i
        has_monitoring = true
        break
      end
    end

    unless has_monitoring
      gaps << {
        type: 'Monitoring gap',
        severity: 'medium',
        description: "Procedure has #{parsed[:procedure_steps].length} steps with no monitoring or progress checking guidance",
        line: nil
      }
    end
  end

  # 3. Outcome verification gap
  if parsed[:procedure_steps].any?
    if !parsed[:has_verification]
      gaps << {
        type: 'Outcome verification gap',
        severity: 'high',
        description: 'Procedure has no .Verification section',
        line: nil
      }
    else
      # Check verification quality
      in_verification = false
      verification_lines = []
      lines.each do |line|
        if line =~ /^\.Verification\s*$/i
          in_verification = true
          next
        end
        if in_verification
          break if line =~ /^\.(?!\.)[A-Z]/
          break if line =~ /^={2,}\s+/
          verification_lines << line unless line =~ /^\s*$/
        end
      end

      has_concrete = verification_lines.any? { |l| l =~ /`[^`]+`/ || l =~ /\boutput\b|\bshows?\b|\bdisplays?\b|\breturns?\b/i }
      unless has_concrete
        gaps << {
          type: 'Outcome verification gap',
          severity: 'medium',
          description: 'Verification section exists but lacks concrete success criteria or example output',
          line: nil
        }
      end
    end
  end

  # 4. Error recovery gap - steps that could fail without guidance
  parsed[:procedure_steps].each do |step|
    # Steps with commands that could fail
    if step[:has_code] && step[:text] !~ /\b(if|error|fail|troubleshoot|issue)\b/i
      # Check if the next step handles errors
      gaps << {
        type: 'Error recovery gap',
        severity: 'low',
        description: "Step at line #{step[:line]} contains commands but no error handling guidance",
        line: step[:line]
      }
    end
  end

  # 5. Decision gap - choices without trade-off guidance
  decision_patterns = [
    /\b(choose|select|pick|decide|option)\b/i,
    /\b(either|or)\b.*\b(either|or)\b/i,
    /\b(depending on|based on your)\b/i,
    /\b(one of the following)\b/i
  ]

  lines.each_with_index do |line, idx|
    decision_patterns.each do |pattern|
      if line =~ pattern
        # Check surrounding context for trade-off guidance
        context_start = [idx - 2, 0].max
        context_end = [idx + 5, lines.length - 1].min
        context = lines[context_start..context_end].join(' ')

        unless context =~ /\b(trade.?off|advantage|disadvantage|benefit|drawback|impact|performance|security|recommend)\b/i
          gaps << {
            type: 'Decision gap',
            severity: 'medium',
            description: "Decision point at line #{idx + 1} without trade-off guidance: #{line.strip[0..80]}",
            line: idx + 1
          }
        end
        break
      end
    end
  end

  # 6. Rollback gap - destructive operations without undo
  destructive_patterns = [
    /\b(delete|remove|destroy|drop|truncate|purge|erase|wipe)\b/i,
    /\boc delete\b/i,
    /\bkubectl delete\b/i,
    /\brm\s+-rf?\b/i,
    /\b(force|--force)\b/i
  ]

  lines.each_with_index do |line, idx|
    destructive_patterns.each do |pattern|
      if line =~ pattern
        # Check surrounding context for rollback/backup guidance
        context_start = [idx - 5, 0].max
        context_end = [idx + 5, lines.length - 1].min
        context = lines[context_start..context_end].join(' ')

        unless context =~ /\b(backup|back.?up|undo|rollback|roll.?back|restore|recover|revert|snapshot)\b/i
          gaps << {
            type: 'Rollback gap',
            severity: 'high',
            description: "Destructive operation at line #{idx + 1} without rollback guidance: #{line.strip[0..80]}",
            line: idx + 1
          }
          break
        end
      end
    end
  end

  # Deduplicate error recovery gaps (keep max 3)
  error_gaps = gaps.select { |g| g[:type] == 'Error recovery gap' }
  if error_gaps.length > 3
    gaps.reject! { |g| g[:type] == 'Error recovery gap' }
    gaps.concat(error_gaps.first(3))
    gaps << {
      type: 'Error recovery gap',
      severity: 'low',
      description: "... and #{error_gaps.length - 3} more steps without error handling guidance",
      line: nil
    }
  end

  {
    file: path,
    title: parsed[:title],
    content_type: parsed[:content_type],
    step_count: parsed[:procedure_steps].length,
    has_prerequisites: parsed[:has_prerequisites],
    has_verification: parsed[:has_verification],
    gap_count: gaps.length,
    gaps_by_severity: {
      high: gaps.count { |g| g[:severity] == 'high' },
      medium: gaps.count { |g| g[:severity] == 'medium' },
      low: gaps.count { |g| g[:severity] == 'low' }
    },
    gap_types: GAP_TYPES,
    gaps: gaps
  }
end

# Parse command line arguments
input_file = nil
json_output = false
dry_run = false

i = 0
while i < ARGV.length
  arg = ARGV[i]
  case arg
  when '--json', '-j'
    json_output = true
    i += 1
  when '--dry-run', '-n'
    dry_run = true
    i += 1
  when '--help', '-h'
    puts "Usage: ruby jtbd_gap_analysis.rb <file.adoc> [--json] [--dry-run]"
    puts ""
    puts "Analyze AsciiDoc procedures for JTBD documentation gaps."
    puts ""
    puts "Gap Types:"
    GAP_TYPES.each { |gt| puts "  - #{gt}" }
    puts ""
    puts "Options:"
    puts "  --json      Output as JSON"
    puts "  --dry-run   Show what would be extracted without processing"
    puts "  --help      Show this help message"
    exit 0
  else
    input_file = arg
    i += 1
  end
end

if input_file.nil?
  puts "Usage: ruby jtbd_gap_analysis.rb <file.adoc> [--json] [--dry-run]"
  exit 1
end

unless File.exist?(input_file)
  puts "Error: File not found: #{input_file}"
  exit 1
end

if dry_run
  puts "#{input_file}: Would analyze for JTBD documentation gaps"
  exit 0
end

result = analyze_gaps(input_file)

if json_output
  require 'json'
  puts JSON.pretty_generate(result)
else
  puts "File: #{result[:file]}"
  puts "Title: #{result[:title] || '(none)'}"
  puts "Content Type: #{result[:content_type] || '(not set)'}"
  puts "Procedure Steps: #{result[:step_count]}"
  puts "Has Prerequisites: #{result[:has_prerequisites]}"
  puts "Has Verification: #{result[:has_verification]}"
  puts ""
  puts "Gaps Found: #{result[:gap_count]}"
  puts "  High: #{result[:gaps_by_severity][:high]}"
  puts "  Medium: #{result[:gaps_by_severity][:medium]}"
  puts "  Low: #{result[:gaps_by_severity][:low]}"

  if result[:gaps].any?
    puts ""
    puts "Gap Details:"
    result[:gaps].each_with_index do |gap, idx|
      line_str = gap[:line] ? " (line #{gap[:line]})" : ""
      puts "  #{idx + 1}. [#{gap[:severity].upcase}] #{gap[:type]}#{line_str}"
      puts "     #{gap[:description]}"
    end
  else
    puts ""
    puts "No gaps detected."
  end
end
