#!/usr/bin/env ruby
# jtbd_identify.rb
# Extract metadata from AsciiDoc files for JTBD job identification.
# Outputs title, content type, abstract, and executor hints for LLM analysis.
# Usage: ruby jtbd_identify.rb <file.adoc> [--json] [--dry-run]

require_relative '../../../lib/asciidoc_parser'

def process_file(path)
  parsed = AsciidocParser.parse(path)

  {
    file: path,
    title: parsed[:title],
    content_type: parsed[:content_type],
    abstract: parsed[:abstract],
    executor_hints: parsed[:executor_hints],
    has_prerequisites: parsed[:has_prerequisites],
    has_verification: parsed[:has_verification],
    heading_count: parsed[:headings].length,
    include_count: parsed[:includes].length,
    step_count: parsed[:procedure_steps].length
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
    puts "Usage: ruby jtbd_identify.rb <file.adoc> [--json] [--dry-run]"
    puts ""
    puts "Extract metadata from AsciiDoc files for JTBD job identification."
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
  puts "Usage: ruby jtbd_identify.rb <file.adoc> [--json] [--dry-run]"
  exit 1
end

unless File.exist?(input_file)
  puts "Error: File not found: #{input_file}"
  exit 1
end

if dry_run
  puts "#{input_file}: Would extract JTBD identification metadata"
  exit 0
end

result = process_file(input_file)

if json_output
  require 'json'
  puts JSON.pretty_generate(result)
else
  puts "File: #{result[:file]}"
  puts "Title: #{result[:title] || '(none)'}"
  puts "Content Type: #{result[:content_type] || '(not set)'}"
  puts "Abstract: #{result[:abstract] || '(none)'}"
  puts "Executor Hints: #{result[:executor_hints].empty? ? '(none)' : result[:executor_hints].join('; ')}"
  puts "Has Prerequisites: #{result[:has_prerequisites]}"
  puts "Has Verification: #{result[:has_verification]}"
  puts "Headings: #{result[:heading_count]}"
  puts "Includes: #{result[:include_count]}"
  puts "Procedure Steps: #{result[:step_count]}"
end
