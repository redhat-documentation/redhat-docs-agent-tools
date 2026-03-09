#!/usr/bin/env ruby
# frozen_string_literal: true

#
# validate_assembly.rb - Validate an assembly and all included modules with Vale
#
# Usage: validate_assembly.rb <assembly.adoc> [options]
#
# Options:
#   --recursive           Include nested includes (snippets in modules)
#   --report-only         Just report issues, don't invoke fix skills
#   --output-format=FMT   Output format: text (default), json, summary
#   --vale-config=PATH    Path to .vale.ini config file
#   -h, --help            Show this help message
#

require 'json'
require 'pathname'
require 'optparse'
require 'fileutils'

# ANSI color codes
RED = "\e[31m"
GREEN = "\e[32m"
YELLOW = "\e[33m"
BLUE = "\e[34m"
CYAN = "\e[36m"
BOLD = "\e[1m"
RESET = "\e[0m"

# Global options
OPTIONS = {
  recursive: false,
  report_only: false,
  output_format: 'text',
  vale_config: nil
}

def usage
  puts <<~USAGE
    Usage: #{File.basename($PROGRAM_NAME)} <assembly.adoc> [options]

    Validate an assembly and all included modules using Vale.

    Options:
      --recursive           Include nested includes (snippets in modules)
      --report-only         Just report issues, don't invoke fix skills
      --output-format=FMT   Output format: text (default), json, summary
      --vale-config=PATH    Path to .vale.ini config file
      -h, --help            Show this help message

    Examples:
      #{File.basename($PROGRAM_NAME)} assemblies/getting-started.adoc
      #{File.basename($PROGRAM_NAME)} assemblies/user-guide.adoc --recursive
      #{File.basename($PROGRAM_NAME)} master.adoc --output-format=json
  USAGE
  exit 0
end

def error(message)
  warn "#{RED}Error:#{RESET} #{message}"
  exit 1
end

def warn_msg(message)
  warn "#{YELLOW}Warning:#{RESET} #{message}"
end

def info(message)
  puts "#{CYAN}Info:#{RESET} #{message}"
end

def success(message)
  puts "#{GREEN}✓#{RESET} #{message}"
end

# Extract include directives from an AsciiDoc file
def extract_includes(file_path)
  includes = []
  base_dir = File.dirname(file_path)

  File.readlines(file_path).each do |line|
    # Match: include::path/to/file.adoc[] or include::path/to/file.adoc[opts]
    if line =~ /^\s*include::([^\[]+)/
      include_path = Regexp.last_match(1).strip

      # Skip paths with unresolved attributes
      if include_path.include?('{')
        warn_msg "Skipping unresolved attribute: #{include_path}"
        next
      end

      # Resolve relative path from the including file's directory
      include_path = File.expand_path(include_path, base_dir) unless include_path.start_with?('/')

      includes << include_path
    end
  end

  includes
rescue Errno::ENOENT
  warn_msg "File not found: #{file_path}"
  []
end

# Recursively find all includes
def find_includes_recursive(file_path, visited = {})
  # Normalize the file path
  file_path = File.expand_path(file_path)

  # Prevent infinite loops
  return [] if visited[file_path]
  visited[file_path] = true

  # Check if file exists
  unless File.exist?(file_path)
    warn_msg "Include not found: #{file_path}"
    return [file_path] # Include in list to show it's referenced but missing
  end

  # Start with this file
  all_files = [file_path]

  # Find includes in this file
  includes = extract_includes(file_path)

  # Recursively process each include
  includes.each do |include_path|
    all_files.concat(find_includes_recursive(include_path, visited))
  end

  all_files
end

# Detect content type from an AsciiDoc file
def detect_content_type(file_path)
  return 'MISSING' unless File.exist?(file_path)

  content = File.read(file_path, encoding: 'UTF-8')

  # Check for explicit content type attribute
  if content =~ /:_mod-docs-content-type:\s*(\w+)/i
    return Regexp.last_match(1).upcase
  end

  # Try to infer from filename or structure
  basename = File.basename(file_path, '.adoc')

  return 'ASSEMBLY' if basename.include?('master') || basename.include?('assembly')
  return 'CONCEPT' if basename.start_with?('con-')
  return 'PROCEDURE' if basename.start_with?('proc-')
  return 'REFERENCE' if basename.start_with?('ref-')
  return 'SNIPPET' if file_path.include?('/snippets/')

  'UNKNOWN'
rescue StandardError
  'ERROR'
end

# Run Vale on a list of files
def run_vale(files, vale_config = nil)
  existing_files = files.select { |f| File.exist?(f) }

  if existing_files.empty?
    warn_msg 'No existing files to validate'
    return {}
  end

  # Build Vale command
  vale_cmd = ['vale', '--output=JSON']
  vale_cmd << "--config=#{vale_config}" if vale_config
  vale_cmd.concat(existing_files)

  # Run Vale
  info "Running Vale on #{existing_files.size} files..."
  vale_output = `#{vale_cmd.join(' ')} 2>&1`
  exit_code = $?.exitstatus

  # Vale returns:
  # 0 = no errors
  # 1 = errors found
  # 2 = Vale error (config issue, etc.)
  if exit_code == 2
    error "Vale configuration error:\n#{vale_output}"
  end

  # Parse JSON output
  begin
    JSON.parse(vale_output)
  rescue JSON::ParserError
    warn_msg "Failed to parse Vale output as JSON"
    {}
  end
end

# Print assembly structure
def print_assembly_structure(assembly_file, all_files)
  puts "\n#{BOLD}Assembly structure:#{RESET}"
  puts "#{BLUE}#{assembly_file}#{RESET} (#{detect_content_type(assembly_file)})"

  all_files[1..].each_with_index do |file, idx|
    is_last = idx == all_files.size - 2
    prefix = is_last ? '└──' : '├──'
    relative_path = Pathname.new(file).relative_path_from(Pathname.new(Dir.pwd))
    content_type = detect_content_type(file)
    status = File.exist?(file) ? '' : " #{RED}(MISSING)#{RESET}"
    puts "#{prefix} #{relative_path} (#{content_type})#{status}"
  end

  puts
end

# Print Vale results summary
def print_vale_summary(vale_results, all_files)
  total_issues = 0
  files_with_issues = 0
  issue_counts = Hash.new(0)

  vale_results.each do |file, issues|
    next if issues.empty?

    files_with_issues += 1
    issues.each do |issue|
      total_issues += 1
      # Extract rule name from Check field (e.g., "AsciiDocDITA.ContentType" -> "ContentType")
      rule = issue['Check'].split('.').last
      issue_counts[rule] += 1
    end
  end

  puts "\n#{BOLD}Vale Report Summary:#{RESET}"
  puts "#{CYAN}═════════════════════#{RESET}"
  puts "Total files validated: #{all_files.size}"
  puts "Files with issues: #{files_with_issues}"
  puts "Total issues: #{total_issues}"

  if issue_counts.any?
    puts "\n#{BOLD}Issues by type:#{RESET}"
    issue_counts.sort_by { |_k, v| -v }.each do |rule, count|
      puts "  #{rule}: #{count}"
    end
  end

  puts
end

# Print detailed Vale results
def print_vale_results(vale_results, base_dir)
  puts "\n#{BOLD}Vale Report by File:#{RESET}"
  puts "#{CYAN}════════════════════#{RESET}\n"

  vale_results.each do |file, issues|
    relative_path = Pathname.new(file).relative_path_from(Pathname.new(base_dir))

    if issues.empty?
      success "#{relative_path}: No issues"
    else
      puts "\n#{YELLOW}⚠#{RESET}  #{BOLD}#{relative_path}#{RESET} (#{issues.size} issues)"
      issues.each do |issue|
        severity = issue['Severity'].upcase
        severity_color = severity == 'ERROR' ? RED : YELLOW
        rule = issue['Check'].split('.').last
        line = issue['Line']
        message = issue['Message']

        puts "  #{severity_color}[#{severity}]#{RESET} #{rule} (line #{line}): #{message}"
      end
    end
  end

  puts
end

# Main execution
def main
  # Parse command line arguments
  parser = OptionParser.new do |opts|
    opts.on('--recursive', 'Include nested includes') { OPTIONS[:recursive] = true }
    opts.on('--report-only', 'Just report, don\'t fix') { OPTIONS[:report_only] = true }
    opts.on('--output-format=FORMAT', %w[text json summary], 'Output format') do |fmt|
      OPTIONS[:output_format] = fmt
    end
    opts.on('--vale-config=PATH', 'Path to .vale.ini') { |path| OPTIONS[:vale_config] = path }
    opts.on('-h', '--help', 'Show help') { usage }
  end

  parser.parse!

  # Validate input
  assembly_file = ARGV[0]
  error 'No input file specified. Use -h for help.' if assembly_file.nil?
  error "File not found: #{assembly_file}" unless File.exist?(assembly_file)

  # Normalize assembly path
  assembly_file = File.expand_path(assembly_file)
  base_dir = File.dirname(assembly_file)

  # Find all includes
  info "Analyzing assembly: #{assembly_file}"
  all_files = if OPTIONS[:recursive]
                find_includes_recursive(assembly_file)
              else
                # Non-recursive: only get direct includes
                [assembly_file] + extract_includes(assembly_file).map { |f| File.expand_path(f) }
              end

  all_files.uniq!

  # Print assembly structure
  print_assembly_structure(assembly_file, all_files) if OPTIONS[:output_format] == 'text'

  # Run Vale
  vale_results = run_vale(all_files, OPTIONS[:vale_config])

  # Output results based on format
  case OPTIONS[:output_format]
  when 'json'
    puts JSON.pretty_generate(vale_results)
  when 'summary'
    print_vale_summary(vale_results, all_files)
  when 'text'
    print_vale_summary(vale_results, all_files)
    print_vale_results(vale_results, base_dir)
  end

  # Exit with appropriate code
  has_errors = vale_results.any? { |_file, issues| issues.any? { |i| i['Severity'] == 'error' } }
  exit(has_errors ? 1 : 0)
end

# Run if executed directly
main if __FILE__ == $PROGRAM_NAME
