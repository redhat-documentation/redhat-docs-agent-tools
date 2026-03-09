#!/usr/bin/env ruby
# chop_reduced_asciidoc.rb
# frozen_string_literal: true

# Chop Reduced AsciiDoc
#
# This script takes a reduced/flattened AsciiDoc file (output from asciidoctor-reducer)
# and chops it into separate module files based on section headings (h1-h3).
#
# Output structure:
#   tmp/
#   ├── <basename>.adoc           # New assembly with include directives
#   └── includes/
#       ├── <section-id-1>.adoc   # First section as module
#       ├── <section-id-2>.adoc   # Second section as module
#       └── ...
#
# Usage:
#   ruby chop_reduced_asciidoc.rb <reduced-file.adoc> [options]
#
# Options:
#   -o, --output DIR   Output directory (default: tmp/)
#   -n, --dry-run      Show what would be done without writing files
#   -h, --help         Show help message

require 'fileutils'

class ChopReducedAsciidoc
  # Section heading pattern (= to ===, i.e., h1-h3)
  HEADING_PATTERN = /^(={1,3})\s+(.+)$/

  # ID attribute pattern
  ID_PATTERN = /^\[id=["']([^"']+)["']\]/

  # Discrete heading attribute
  DISCRETE_PATTERN = /^\[discrete\]/i

  # Context variable pattern to strip from IDs for filenames
  CONTEXT_PATTERN = /_\{context\}$/

  # Leveloffset directive patterns
  LEVELOFFSET_SET_PATTERN = /^:leveloffset:\s*([+-]?\d+)$/
  LEVELOFFSET_RESET_PATTERN = /^:leveloffset!:$/

  # Module metadata attributes that belong with the following section
  MODULE_ATTR_PATTERN = /^:(_module-type|_mod-docs-content-type|parent-context):\s*(.*)$/

  def initialize(input_file, options = {})
    @input_file = File.expand_path(input_file)
    @output_dir = options[:output_dir] || 'tmp'
    @dry_run = options[:dry_run] || false
    @includes_dir = File.join(@output_dir, 'includes')
    @basename = File.basename(@input_file, '.*')
    @modules = []
    @header_lines = []
    @stats = { modules_created: 0, assembly_created: false }
  end

  def chop
    unless File.exist?(@input_file)
      return { error: "File not found: #{@input_file}" }
    end

    lines = File.readlines(@input_file, chomp: true)

    # Parse the document into sections
    parse_document(lines)

    if @modules.empty?
      puts "No sections found to chop in #{@input_file}"
      return { error: "No sections found" }
    end

    # Create output directories
    unless @dry_run
      FileUtils.mkdir_p(@includes_dir)
    end

    # Write module files
    write_modules

    # Write new assembly file
    write_assembly

    print_summary

    {
      input: @input_file,
      output_dir: @output_dir,
      modules_created: @stats[:modules_created],
      dry_run: @dry_run
    }
  end

  private

  def parse_document(lines)
    current_section = nil
    pending_id = nil
    pending_discrete = false
    pending_module_attrs = []  # Track module attributes for next section
    in_header = true
    header_title_found = false
    current_leveloffset = 0  # Track cumulative leveloffset

    lines.each do |line|
      # Check for leveloffset directives (don't include in output)
      if match = line.match(LEVELOFFSET_SET_PATTERN)
        offset_value = match[1]
        if offset_value.start_with?('+') || offset_value.start_with?('-')
          # Relative offset like +1, +2, -1
          current_leveloffset += offset_value.to_i
        else
          # Absolute offset
          current_leveloffset = offset_value.to_i
        end
        next
      end

      if line.match?(LEVELOFFSET_RESET_PATTERN)
        current_leveloffset = 0
        next
      end

      # Check for module metadata attributes (belong with next section)
      if line.match?(MODULE_ATTR_PATTERN)
        pending_module_attrs << line
        next
      end

      # Check for discrete marker
      if line.match?(DISCRETE_PATTERN)
        pending_discrete = true
        current_section[:lines] << line if current_section
        next
      end

      # Check for ID attribute before heading
      if match = line.match(ID_PATTERN)
        pending_id = match[1]
        # Don't add to current section yet - wait to see if heading follows
        next
      end

      # Check for section heading
      if match = line.match(HEADING_PATTERN)
        raw_level = match[1].length
        title = match[2].strip

        # Calculate effective level (raw level + leveloffset)
        effective_level = raw_level + current_leveloffset

        # Skip discrete headings - they stay in the current section
        if pending_discrete
          pending_discrete = false
          current_section[:lines] << "[id=\"#{pending_id}\"]" if pending_id
          current_section[:lines] << line if current_section
          pending_id = nil
          pending_module_attrs = []  # Clear pending attrs for discrete headings
          next
        end

        # First heading (h1) is the document title - part of header
        if in_header && raw_level == 1 && current_leveloffset == 0 && !header_title_found
          header_title_found = true
          @header_lines << "[id=\"#{pending_id}\"]" if pending_id
          @header_lines << line
          pending_id = nil
          pending_module_attrs = []  # Clear for document title
          next
        end

        # After first h1, we're no longer in header
        in_header = false if header_title_found

        # Chop on effective levels 2-4 (which correspond to h2-h4 in final output)
        # Save previous section
        if current_section
          @modules << current_section
        end

        # Generate ID if none provided
        section_id = pending_id || generate_id(title)

        # Start new section
        current_section = {
          id: section_id,
          title: title,
          raw_level: raw_level,
          effective_level: effective_level,
          lines: []
        }

        # Add pending module attributes first
        pending_module_attrs.each do |attr|
          current_section[:lines] << attr
        end
        current_section[:lines] << "" unless pending_module_attrs.empty?
        pending_module_attrs = []

        # Add the ID and heading to the section (normalize to single = for modules)
        current_section[:lines] << "[id=\"#{section_id}\"]"
        current_section[:lines] << "= #{title}"
        pending_id = nil

      elsif in_header
        # Still in header section (before first choppable section)
        # If we have a pending ID, add it
        @header_lines << "[id=\"#{pending_id}\"]" if pending_id
        pending_id = nil
        @header_lines << line unless line.strip.empty? && @header_lines.empty?
      else
        # Regular content - add to current section
        if current_section
          # Add any pending ID that wasn't followed by a heading
          current_section[:lines] << "[id=\"#{pending_id}\"]" if pending_id
          current_section[:lines] << line
        end
        pending_id = nil
        pending_discrete = false
      end
    end

    # Don't forget the last section
    @modules << current_section if current_section
  end

  def generate_id(title)
    # Convert title to kebab-case ID
    title
      .downcase
      .gsub(/[^a-z0-9\s-]/, '')  # Remove special chars
      .gsub(/\s+/, '-')          # Spaces to hyphens
      .gsub(/-+/, '-')           # Collapse multiple hyphens
      .gsub(/^-|-$/, '')         # Trim leading/trailing hyphens
  end

  def strip_context(id)
    # Remove _{context} suffix from ID for use in filenames
    id.gsub(CONTEXT_PATTERN, '')
  end

  def write_modules
    @modules.each do |mod|
      # Strip _{context} from filename
      clean_id = strip_context(mod[:id])
      filename = "#{clean_id}.adoc"
      filepath = File.join(@includes_dir, filename)

      # Clean up trailing empty lines
      content_lines = mod[:lines].dup
      content_lines.pop while content_lines.last&.strip&.empty?
      content_lines << ""

      content = content_lines.join("\n")

      if @dry_run
        puts "Would create: #{filepath}"
        puts "  Title: #{mod[:title]}"
        puts "  Lines: #{mod[:lines].length}"
      else
        File.write(filepath, content)
        puts "Created: #{filepath}"
      end

      @stats[:modules_created] += 1
    end
  end

  def write_assembly
    assembly_path = File.join(@output_dir, "#{@basename}.adoc")

    content_lines = []

    # Add header content (attributes, title, etc.)
    content_lines.concat(@header_lines)

    content_lines << ""
    content_lines << "// Chopped from: #{File.basename(@input_file)}"
    content_lines << ""

    # Add include directives for each module
    @modules.each do |mod|
      # Strip _{context} from include path
      clean_id = strip_context(mod[:id])

      # Calculate leveloffset based on effective level
      # effective_level 2 (h2) -> +1, effective_level 3 (h3) -> +2, etc.
      # Since modules are normalized to = (h1), we need effective_level - 1
      leveloffset = mod[:effective_level] - 1

      include_line = "include::includes/#{clean_id}.adoc[leveloffset=+#{leveloffset}]"
      content_lines << include_line
      content_lines << ""
    end

    content = content_lines.join("\n")

    if @dry_run
      puts ""
      puts "Would create assembly: #{assembly_path}"
      puts "---"
      puts content
      puts "---"
    else
      File.write(assembly_path, content)
      puts ""
      puts "Created assembly: #{assembly_path}"
    end

    @stats[:assembly_created] = true
  end

  def print_summary
    puts ""
    puts "Summary:"
    puts "  Input: #{@input_file}"
    puts "  Output directory: #{@output_dir}"
    puts "  Modules created: #{@stats[:modules_created]}"
    puts "  Assembly created: #{@stats[:assembly_created]}"

    if @dry_run
      puts ""
      puts "(Dry run - no files written)"
    end
  end
end

# Command-line interface
if __FILE__ == $PROGRAM_NAME
  input_file = nil
  output_dir = nil
  dry_run = false

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
    when '--help', '-h'
      puts <<~HELP
        Usage: ruby chop_reduced_asciidoc.rb <reduced-file.adoc> [options]

        Chop a reduced/flattened AsciiDoc file into separate module files
        based on section headings (h1-h3).

        Options:
          -o, --output DIR   Output directory (default: tmp/)
          -n, --dry-run      Show what would be done without writing files
          -h, --help         Show this help message

        Output structure:
          <output-dir>/
          ├── <basename>.adoc           # New assembly with include directives
          └── includes/
              ├── <section-id-1>.adoc   # First section as module
              ├── <section-id-2>.adoc   # Second section as module
              └── ...

        Example:
          ruby chop_reduced_asciidoc.rb master-reduced.adoc -o tmp/

        The script:
          - Parses the reduced file for section headings (h1-h3)
          - Creates separate module files for each section
          - Strips _{context} from IDs for filenames and includes
          - Preserves section IDs (or generates them from titles)
          - Generates a new assembly file with include directives
      HELP
      exit 0
    else
      input_file = arg
      i += 1
    end
  end

  if input_file.nil?
    puts "Error: No input file specified"
    puts "Usage: ruby chop_reduced_asciidoc.rb <reduced-file.adoc> [options]"
    exit 1
  end

  options = {
    output_dir: output_dir,
    dry_run: dry_run
  }

  chopper = ChopReducedAsciidoc.new(input_file, options)
  result = chopper.chop

  if result[:error]
    puts "Error: #{result[:error]}"
    exit 1
  end
end
