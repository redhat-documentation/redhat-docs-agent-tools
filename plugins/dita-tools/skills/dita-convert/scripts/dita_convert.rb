#!/usr/bin/env ruby
# dita_convert.rb
# Converts AsciiDoc files to DITA 2.0 format (concept, task, reference, ditamap)
# Usage: ruby dita_convert.rb <file.adoc> [-o output_dir] [--dry-run] [--ast]

require_relative 'lib/dita_converter'

# Default output directory
DEFAULT_OUTPUT_DIR = '.claude_docs/dita-convert'

# Command-line interface
if __FILE__ == $0
  input_file = nil
  output_dir = nil
  dry_run = false
  show_ast = false

  i = 0
  while i < ARGV.length
    arg = ARGV[i]
    case arg
    when '-o', '--output'
      if i + 1 < ARGV.length
        output_dir = ARGV[i + 1]
        i += 2
      else
        puts "Error: -o requires an argument"
        exit 1
      end
    when '--dry-run', '-n'
      dry_run = true
      i += 1
    when '--ast', '-a'
      show_ast = true
      i += 1
    when '--help', '-h'
      puts <<~HELP
        Usage: ruby dita_convert.rb <file.adoc> [options]

        Convert AsciiDoc files to DITA 2.0 format.
        Output is automatically validated using DITA-OT (requires 'dita' on PATH).

        Options:
          -o, --output DIR   Write output to DIR (default: .claude_docs/dita-convert/)
          -n, --dry-run      Show what would be done without writing files
          -a, --ast          Show the parsed AST (TOON format if available)
          -h, --help         Show this help message

        Supported content types:
          - ASSEMBLY   -> .ditamap
          - CONCEPT    -> concept.dita
          - PROCEDURE  -> task.dita
          - REFERENCE  -> reference.dita

        Examples:
          ruby dita_convert.rb module.adoc
          ruby dita_convert.rb assembly.adoc -o output/
          ruby dita_convert.rb module.adoc --ast
      HELP
      exit 0
    else
      input_file = arg
      i += 1
    end
  end

  if input_file.nil?
    puts "Error: No input file specified"
    puts "Usage: ruby dita_convert.rb <file.adoc> [options]"
    exit 1
  end

  unless File.exist?(input_file)
    puts "Error: File not found: #{input_file}"
    exit 1
  end

  # Use default output directory if not specified
  output_dir ||= DEFAULT_OUTPUT_DIR

  options = {
    output_dir: output_dir,
    dry_run: dry_run,
    show_ast: show_ast
  }

  converter = DITAConverter.new(input_file, options)
  result = converter.convert

  if result[:error]
    puts "Error: #{result[:error]}"
    exit 1
  end

  puts "\nConversion complete:"
  puts "  Type: #{result[:type]}"
  puts "  Input: #{result[:input]}"
  puts "  Output: #{result[:output]}"

  if result[:modules]
    puts "  Modules converted: #{result[:modules].length}"
    result[:modules].each do |mod|
      puts "    - #{mod[:type]}: #{mod[:output]}"
    end
  end
end
