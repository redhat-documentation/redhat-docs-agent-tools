#!/usr/bin/env ruby
# jtbd_categorize.rb
# Parse assembly TOC structure with ordering and nesting for JTBD categorization.
# Maps modules to Red Hat JTBD categories: Discover, Get Started, Plan, Install,
# Configure, Observe, Troubleshoot.
# Usage: ruby jtbd_categorize.rb <assembly.adoc> [--json] [--dry-run]

require_relative '../../../lib/asciidoc_parser'

JTBD_CATEGORIES = [
  'Discover',
  'Get Started',
  'Plan',
  'Install',
  'Configure',
  'Observe',
  'Troubleshoot'
].freeze

def build_toc(assembly_path)
  unless File.exist?(assembly_path)
    return { error: "File not found: #{assembly_path}" }
  end

  parsed = AsciidocParser.parse(assembly_path)
  base_dir = File.dirname(File.expand_path(assembly_path))

  toc_entries = []

  parsed[:includes].each_with_index do |inc, idx|
    inc_path = inc[:path]
    # Skip attribute-based paths
    if inc_path.include?('{')
      toc_entries << {
        order: idx + 1,
        path: inc_path,
        title: '(unresolved attribute path)',
        content_type: nil,
        abstract: nil,
        include_line: inc[:line]
      }
      next
    end

    # Resolve relative path
    abs_path = inc_path
    unless inc_path.start_with?('/')
      abs_path = File.expand_path(File.join(base_dir, inc_path))
    end

    if File.exist?(abs_path)
      mod_parsed = AsciidocParser.parse(abs_path)
      toc_entries << {
        order: idx + 1,
        path: inc_path,
        resolved_path: abs_path,
        title: mod_parsed[:title],
        content_type: mod_parsed[:content_type],
        abstract: mod_parsed[:abstract],
        include_line: inc[:line],
        is_assembly: mod_parsed[:includes].length >= 2,
        child_count: mod_parsed[:includes].length
      }
    else
      toc_entries << {
        order: idx + 1,
        path: inc_path,
        resolved_path: abs_path,
        title: '(file not found)',
        content_type: nil,
        abstract: nil,
        include_line: inc[:line]
      }
    end
  end

  {
    assembly: assembly_path,
    assembly_title: parsed[:title],
    entry_count: toc_entries.length,
    categories: JTBD_CATEGORIES,
    entries: toc_entries
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
    puts "Usage: ruby jtbd_categorize.rb <assembly.adoc> [--json] [--dry-run]"
    puts ""
    puts "Parse assembly TOC structure for JTBD categorization."
    puts ""
    puts "JTBD Categories:"
    JTBD_CATEGORIES.each { |cat| puts "  - #{cat}" }
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
  puts "Usage: ruby jtbd_categorize.rb <assembly.adoc> [--json] [--dry-run]"
  exit 1
end

unless File.exist?(input_file)
  puts "Error: File not found: #{input_file}"
  exit 1
end

if dry_run
  puts "#{input_file}: Would extract TOC structure for JTBD categorization"
  exit 0
end

result = build_toc(input_file)

if result[:error]
  puts "Error: #{result[:error]}"
  exit 1
end

if json_output
  require 'json'
  puts JSON.pretty_generate(result)
else
  puts "Assembly: #{result[:assembly]}"
  puts "Assembly Title: #{result[:assembly_title] || '(untitled)'}"
  puts "TOC Entries: #{result[:entry_count]}"
  puts ""
  puts "JTBD Categories: #{JTBD_CATEGORIES.join(', ')}"
  puts ""
  puts "TOC Structure:"
  result[:entries].each do |entry|
    type_str = entry[:content_type] ? "[#{entry[:content_type]}]" : "[UNKNOWN]"
    assembly_marker = entry[:is_assembly] ? " (assembly, #{entry[:child_count]} children)" : ""
    puts "  #{entry[:order]}. #{type_str} #{entry[:title] || '(untitled)'}#{assembly_marker}"
    puts "     Path: #{entry[:path]}"
    puts "     Abstract: #{entry[:abstract]}" if entry[:abstract]
  end
end
