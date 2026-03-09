#!/usr/bin/env ruby
# jtbd_rewrite.rb
# Extract title, tables, prerequisites, and verification sections for
# outcome-oriented rewriting.
# Usage: ruby jtbd_rewrite.rb <file.adoc> [--json] [--dry-run]

require_relative '../../../lib/asciidoc_parser'

def analyze_title(title)
  return nil unless title

  issues = []
  # Check for noun-based titles (feature-centric)
  if title =~ /^[A-Z][a-z]+ (?:configuration|settings|options|parameters|properties)$/i
    issues << 'Noun-based title (feature-centric, not outcome-oriented)'
  end

  # Check for product name in title
  if title =~ /(?:OpenShift|Kubernetes|RHEL|Red Hat)/
    issues << 'Contains product name (consider removing for reusability)'
  end

  # Check if title uses gerund (good for procedures)
  is_gerund = title =~ /^[A-Z][a-z]+ing\b/

  { title: title, issues: issues, is_gerund: is_gerund }
end

def analyze_tables(tables)
  tables.map do |tbl|
    analysis = {
      line_start: tbl[:line_start],
      line_end: tbl[:line_end],
      headers: tbl[:headers],
      row_count: tbl[:rows].length,
      is_parameter_table: false,
      missing_tradeoff_column: false
    }

    # Detect parameter/option tables
    header_text = tbl[:headers].join(' ').downcase
    if header_text =~ /param|option|setting|field|variable|property|attribute/
      analysis[:is_parameter_table] = true
      # Check if trade-off/description columns exist
      unless header_text =~ /trade.?off|impact|effect|consequence|what it controls/
        analysis[:missing_tradeoff_column] = true
      end
    end

    analysis
  end
end

def analyze_prerequisites(parsed)
  return nil unless parsed[:has_prerequisites]

  lines = parsed[:lines]
  prereq_lines = []
  in_prereqs = false
  has_verification_commands = false

  lines.each do |line|
    if line =~ /^\.Prerequisites\s*$/i
      in_prereqs = true
      next
    end

    if in_prereqs
      break if line =~ /^\.(?!\.)[A-Z]/ # Next block title
      break if line =~ /^={2,}\s+/ # Next heading

      if line =~ /^\*\s+(.+)$/ || line =~ /^-\s+(.+)$/
        prereq_text = Regexp.last_match(1)
        prereq_lines << prereq_text
        # Check for verification commands
        if prereq_text =~ /`[^`]+`/ || prereq_text =~ /\boc\b|\bkubectl\b|\bcurl\b|\bverify\b|\bcheck\b|\bconfirm\b/i
          has_verification_commands = true
        end
      end
    end
  end

  {
    items: prereq_lines,
    has_verification_commands: has_verification_commands
  }
end

def analyze_verification(parsed)
  return nil unless parsed[:has_verification]

  lines = parsed[:lines]
  verification_lines = []
  in_verification = false
  has_concrete_criteria = false

  lines.each do |line|
    if line =~ /^\.Verification\s*$/i
      in_verification = true
      next
    end

    if in_verification
      break if line =~ /^\.(?!\.)[A-Z]/ # Next block title
      break if line =~ /^={2,}\s+/ # Next heading

      unless line =~ /^\s*$/
        verification_lines << line
        # Check for concrete success criteria
        if line =~ /`[^`]+`/ || line =~ /output|shows?|displays?|returns?|expect|confirm/i
          has_concrete_criteria = true
        end
      end
    end
  end

  {
    lines: verification_lines,
    has_concrete_criteria: has_concrete_criteria,
    is_vague: !has_concrete_criteria && verification_lines.any?
  }
end

def process_file(path)
  parsed = AsciidocParser.parse(path)

  {
    file: path,
    title_analysis: analyze_title(parsed[:title]),
    content_type: parsed[:content_type],
    abstract: parsed[:abstract],
    table_analysis: analyze_tables(parsed[:tables]),
    prerequisite_analysis: analyze_prerequisites(parsed),
    verification_analysis: analyze_verification(parsed),
    step_count: parsed[:procedure_steps].length,
    executor_hints: parsed[:executor_hints]
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
    puts "Usage: ruby jtbd_rewrite.rb <file.adoc> [--json] [--dry-run]"
    puts ""
    puts "Extract title, tables, prerequisites, and verification for outcome-oriented rewriting."
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
  puts "Usage: ruby jtbd_rewrite.rb <file.adoc> [--json] [--dry-run]"
  exit 1
end

unless File.exist?(input_file)
  puts "Error: File not found: #{input_file}"
  exit 1
end

if dry_run
  puts "#{input_file}: Would extract rewrite analysis metadata"
  exit 0
end

result = process_file(input_file)

if json_output
  require 'json'
  puts JSON.pretty_generate(result)
else
  puts "File: #{result[:file]}"
  puts "Content Type: #{result[:content_type] || '(not set)'}"

  if result[:title_analysis]
    puts ""
    puts "Title Analysis:"
    puts "  Title: #{result[:title_analysis][:title]}"
    puts "  Gerund form: #{result[:title_analysis][:is_gerund] ? 'yes' : 'no'}"
    result[:title_analysis][:issues].each { |issue| puts "  Issue: #{issue}" }
  end

  puts ""
  puts "Abstract: #{result[:abstract] || '(none)'}"

  if result[:table_analysis].any?
    puts ""
    puts "Tables (#{result[:table_analysis].length}):"
    result[:table_analysis].each_with_index do |tbl, idx|
      puts "  Table #{idx + 1} (lines #{tbl[:line_start]}-#{tbl[:line_end]}):"
      puts "    Headers: #{tbl[:headers].join(' | ')}"
      puts "    Rows: #{tbl[:row_count]}"
      puts "    Parameter table: #{tbl[:is_parameter_table] ? 'yes' : 'no'}"
      puts "    Missing trade-off column: yes" if tbl[:missing_tradeoff_column]
    end
  end

  if result[:prerequisite_analysis]
    puts ""
    puts "Prerequisites:"
    puts "  Items: #{result[:prerequisite_analysis][:items].length}"
    puts "  Has verification commands: #{result[:prerequisite_analysis][:has_verification_commands] ? 'yes' : 'no'}"
    result[:prerequisite_analysis][:items].each { |item| puts "    - #{item}" }
  end

  if result[:verification_analysis]
    puts ""
    puts "Verification:"
    puts "  Lines: #{result[:verification_analysis][:lines].length}"
    puts "  Has concrete criteria: #{result[:verification_analysis][:has_concrete_criteria] ? 'yes' : 'no'}"
    puts "  Is vague: #{result[:verification_analysis][:is_vague] ? 'yes' : 'no'}"
  end

  puts ""
  puts "Procedure Steps: #{result[:step_count]}"
  puts "Executor Hints: #{result[:executor_hints].empty? ? '(none)' : result[:executor_hints].join('; ')}"
end
