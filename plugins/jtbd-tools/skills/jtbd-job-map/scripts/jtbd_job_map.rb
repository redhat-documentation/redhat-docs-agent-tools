#!/usr/bin/env ruby
# jtbd_job_map.rb
# Parse assembly includes recursively and extract module metadata for
# Universal Job Map step mapping.
# Usage: ruby jtbd_job_map.rb <assembly.adoc> [--json] [--dry-run]

require_relative '../../../lib/asciidoc_parser'

# Recursively resolve includes and parse each module
def build_module_list(assembly_path, visited = {})
  abs_path = File.expand_path(assembly_path)
  return [] if visited[abs_path]
  visited[abs_path] = true

  unless File.exist?(abs_path)
    return [{ file: abs_path, error: 'File not found' }]
  end

  parsed = AsciidocParser.parse(abs_path)
  base_dir = File.dirname(abs_path)

  modules = []

  # Add the assembly itself
  modules << {
    file: abs_path,
    title: parsed[:title],
    content_type: parsed[:content_type],
    abstract: parsed[:abstract],
    has_prerequisites: parsed[:has_prerequisites],
    has_verification: parsed[:has_verification],
    step_count: parsed[:procedure_steps].length,
    heading_count: parsed[:headings].length,
    include_count: parsed[:includes].length
  }

  # Recurse into includes
  parsed[:includes].each do |inc|
    inc_path = inc[:path]
    # Skip attribute-based paths
    next if inc_path.include?('{')

    # Resolve relative path
    unless inc_path.start_with?('/')
      inc_path = File.join(base_dir, inc_path)
    end
    inc_path = File.expand_path(inc_path)

    child_modules = build_module_list(inc_path, visited)
    modules.concat(child_modules)
  end

  modules
end

JOB_MAP_STEPS = [
  'Define',
  'Locate',
  'Prepare',
  'Confirm',
  'Execute',
  'Monitor',
  'Modify',
  'Conclude'
].freeze

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
    puts "Usage: ruby jtbd_job_map.rb <assembly.adoc> [--json] [--dry-run]"
    puts ""
    puts "Parse assembly includes and extract module metadata for Universal Job Map mapping."
    puts ""
    puts "Universal Job Map Steps:"
    JOB_MAP_STEPS.each_with_index { |step, i| puts "  #{i + 1}. #{step}" }
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
  puts "Usage: ruby jtbd_job_map.rb <assembly.adoc> [--json] [--dry-run]"
  exit 1
end

unless File.exist?(input_file)
  puts "Error: File not found: #{input_file}"
  exit 1
end

if dry_run
  puts "#{input_file}: Would extract module metadata for Job Map analysis"
  exit 0
end

modules = build_module_list(input_file)

if json_output
  require 'json'
  output = {
    assembly: input_file,
    job_map_steps: JOB_MAP_STEPS,
    module_count: modules.length,
    modules: modules
  }
  puts JSON.pretty_generate(output)
else
  puts "Assembly: #{input_file}"
  puts "Total modules: #{modules.length}"
  puts ""
  puts "Universal Job Map Steps: #{JOB_MAP_STEPS.join(', ')}"
  puts ""
  puts "Modules:"
  modules.each_with_index do |mod, idx|
    if mod[:error]
      puts "  #{idx + 1}. [ERROR] #{mod[:file]}: #{mod[:error]}"
      next
    end
    type_str = mod[:content_type] ? "[#{mod[:content_type]}]" : "[UNKNOWN]"
    puts "  #{idx + 1}. #{type_str} #{mod[:title] || '(untitled)'}"
    puts "     File: #{mod[:file]}"
    puts "     Abstract: #{mod[:abstract]}" if mod[:abstract]
    puts "     Steps: #{mod[:step_count]}" if mod[:step_count] > 0
    puts "     Prerequisites: yes" if mod[:has_prerequisites]
    puts "     Verification: yes" if mod[:has_verification]
  end
end
