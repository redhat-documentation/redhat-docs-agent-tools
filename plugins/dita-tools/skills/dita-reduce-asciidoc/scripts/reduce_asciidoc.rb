#!/usr/bin/env ruby
# normalize_asciidoc.rb
# Wrapper around asciidoctor-reducer to flatten AsciiDoc assemblies
# by expanding all include directives into a single document.
#
# Usage: ruby normalize_asciidoc.rb <file.adoc> [-o output.adoc] [--dry-run] [--preserve-conditionals]

require 'fileutils'

# Check if asciidoctor-reducer is available
begin
  require 'asciidoctor/reducer/api'
rescue LoadError
  puts "Error: asciidoctor-reducer gem is not installed."
  puts "Install it with: gem install asciidoctor-reducer"
  exit 1
end

class AsciiDocNormalizer
  def initialize(input_file, options = {})
    @input_file = File.expand_path(input_file)
    @output_file = options[:output_file]
    @dry_run = options[:dry_run] || false
    @preserve_conditionals = options[:preserve_conditionals] || false
  end

  def normalize
    unless File.exist?(@input_file)
      return { error: "File not found: #{@input_file}" }
    end

    # Build reducer options
    reducer_opts = {
      safe: :unsafe,  # Allow includes from any directory
      preserve_conditionals: @preserve_conditionals
    }

    # Use asciidoctor-reducer to flatten the document
    begin
      doc = Asciidoctor::Reducer.reduce_file(@input_file, reducer_opts)
      output_content = doc.source + "\n"
    rescue => e
      return { error: "Failed to reduce document: #{e.message}" }
    end

    # Determine output path
    output_path = @output_file || generate_output_path

    if @dry_run
      puts "=== Dry Run Output ==="
      puts output_content
      puts "======================"
      puts "\nWould write to: #{output_path}"
    else
      FileUtils.mkdir_p(File.dirname(output_path))
      File.write(output_path, output_content)
      puts "Wrote: #{output_path}"
    end

    {
      input: @input_file,
      output: output_path,
      dry_run: @dry_run
    }
  end

  private

  def generate_output_path
    dir = File.dirname(@input_file)
    base = File.basename(@input_file, '.*')
    ext = File.extname(@input_file)
    File.join(dir, "#{base}-reduced#{ext}")
  end
end

# Command-line interface
if __FILE__ == $0
  input_file = nil
  output_file = nil
  dry_run = false
  preserve_conditionals = false

  i = 0
  while i < ARGV.length
    arg = ARGV[i]
    case arg
    when '-o', '--output'
      if i + 1 < ARGV.length
        output_file = ARGV[i + 1]
        i += 2
      else
        puts "Error: -o requires an argument"
        exit 1
      end
    when '--dry-run', '-n'
      dry_run = true
      i += 1
    when '--preserve-conditionals', '-p'
      preserve_conditionals = true
      i += 1
    when '--help', '-h'
      puts <<~HELP
        Usage: ruby normalize_asciidoc.rb <file.adoc> [options]

        Normalize AsciiDoc files by expanding all include directives into a
        single document using asciidoctor-reducer.

        Options:
          -o, --output FILE          Write output to FILE (default: <input>-reduced.adoc)
          -n, --dry-run              Show what would be done without writing files
          -p, --preserve-conditionals  Keep ifdef/ifndef/endif directives unchanged
          -h, --help                 Show this help message

        Example:
          ruby normalize_asciidoc.rb master.adoc -o flat-master.adoc

        Requirements:
          gem install asciidoctor-reducer

        The script uses asciidoctor-reducer to:
          - Expand all include directives recursively
          - Evaluate preprocessor conditionals (unless --preserve-conditionals)
          - Output a single flattened AsciiDoc file
      HELP
      exit 0
    else
      input_file = arg
      i += 1
    end
  end

  if input_file.nil?
    puts "Error: No input file specified"
    puts "Usage: ruby normalize_asciidoc.rb <file.adoc> [options]"
    exit 1
  end

  options = {
    output_file: output_file,
    dry_run: dry_run,
    preserve_conditionals: preserve_conditionals
  }

  normalizer = AsciiDocNormalizer.new(input_file, options)
  result = normalizer.normalize

  if result[:error]
    puts "Error: #{result[:error]}"
    exit 1
  end
end
