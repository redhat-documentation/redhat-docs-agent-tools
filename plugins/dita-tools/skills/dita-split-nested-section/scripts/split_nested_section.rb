#!/usr/bin/env ruby
# split_nested_section.rb
# frozen_string_literal: true

# Split Nested Sections
#
# Detects nested sections (== or deeper) inside AsciiDoc module files and
# optionally splits them into separate module files. Updates the parent
# assembly to include the new modules.
#
# Usage:
#   ruby split_nested_section.rb <file.adoc> [options]
#
# Options:
#   --dry-run        Show what would be done without writing files
#   --json           Output analysis as JSON
#   --assembly FILE  Specify the parent assembly file to update
#   -h, --help       Show help message

require 'json'
require 'fileutils'

class SplitNestedSection
  HEADING_PATTERN = /^(={1,5})\s+(.+)$/
  ID_PATTERN = /^\[id=["']([^"']+)["']\]/
  CONTENT_TYPE_PATTERN = /^:_mod-docs-content-type:\s*(\w+)/
  ABSTRACT_PATTERN = /^\[role="_abstract"\]/
  DISCRETE_PATTERN = /^\[discrete\]/i
  INCLUDE_PATTERN = /^include::(.+)\[/
  CONTEXT_PATTERN = /\{context\}/

  def initialize(input_file, options = {})
    @input_file = File.expand_path(input_file)
    @dry_run = options[:dry_run] || false
    @json = options[:json] || false
    @assembly = options[:assembly] ? File.expand_path(options[:assembly]) : nil
    @sections = []
    @content_type = nil
    @title_level = nil
    @title = nil
    @title_id = nil
    @is_assembly = false
  end

  def analyze
    unless File.exist?(@input_file)
      error_result("File not found: #{@input_file}")
      return
    end

    lines = File.readlines(@input_file, chomp: true)
    parse_file(lines)

    if @is_assembly
      output_result({
        file: @input_file,
        content_type: @content_type,
        title: @title,
        nested_sections: [],
        message: "File is an assembly (contains include directives). Nested sections in assemblies are expected."
      })
      return
    end

    if @sections.empty?
      output_result({
        file: @input_file,
        content_type: @content_type,
        title: @title,
        nested_sections: [],
        message: "No nested sections found"
      })
      return
    end

    result = {
      file: @input_file,
      content_type: @content_type,
      title: @title,
      title_id: @title_id,
      nested_sections: @sections.map { |s|
        {
          line: s[:line_number],
          level: s[:level],
          heading_markers: s[:heading_markers],
          title: s[:title],
          id: s[:id],
          content_lines: s[:content_line_count],
          suggested_filename: s[:suggested_filename],
          suggested_content_type: s[:suggested_content_type]
        }
      }
    }

    output_result(result)
  end

  def split
    unless File.exist?(@input_file)
      error_result("File not found: #{@input_file}")
      return nil
    end

    lines = File.readlines(@input_file, chomp: true)
    parse_file(lines)

    if @sections.empty?
      puts "No nested sections to split in #{@input_file}"
      return nil
    end

    if @is_assembly
      puts "File is an assembly. Use dita-rework-assembly-intro for assembly content."
      return nil
    end

    created_files = []

    @sections.each do |section|
      new_file = create_module(section)
      created_files << new_file if new_file
    end

    # Update original file to remove nested sections
    update_original(lines)

    # Update assembly if specified
    update_assembly(created_files) if @assembly

    created_files
  end

  private

  def parse_file(lines)
    has_includes = lines.any? { |l| l.match?(INCLUDE_PATTERN) }

    # Detect content type
    lines.each do |line|
      if match = line.match(CONTENT_TYPE_PATTERN)
        @content_type = match[1]
        @is_assembly = @content_type == 'ASSEMBLY'
        break
      end
    end

    # Also check for includes as assembly indicator
    @is_assembly = true if has_includes && @content_type.nil?

    return if @is_assembly

    pending_id = nil
    pending_discrete = false
    title_found = false
    current_section = nil

    lines.each_with_index do |line, index|
      line_number = index + 1

      # Check for discrete heading marker
      if line.match?(DISCRETE_PATTERN)
        pending_discrete = true
        current_section[:lines] << line if current_section
        next
      end

      # Check for ID attribute
      if match = line.match(ID_PATTERN)
        pending_id = match[1]
        current_section[:lines] << line if current_section
        next
      end

      # Check for heading
      if match = line.match(HEADING_PATTERN)
        level = match[1].length
        heading_title = match[2].strip

        # Skip discrete headings
        if pending_discrete
          pending_discrete = false
          current_section[:lines] << line if current_section
          pending_id = nil
          next
        end

        if !title_found
          # First heading is the document title
          @title_level = level
          @title = heading_title
          @title_id = pending_id
          title_found = true
          pending_id = nil
          next
        end

        # This is a nested section
        # Save previous nested section if any
        if current_section
          finalize_section(current_section)
          @sections << current_section
        end

        section_id = pending_id || generate_id(heading_title)

        current_section = {
          line_number: line_number,
          level: level,
          heading_markers: match[1],
          title: heading_title,
          id: section_id,
          lines: [],
          content_line_count: 0,
          suggested_filename: suggest_filename(section_id),
          suggested_content_type: suggest_content_type(heading_title)
        }

        pending_id = nil
      else
        if current_section
          current_section[:lines] << line
        end
        pending_id = nil unless line.strip.empty?
        pending_discrete = false
      end
    end

    # Don't forget last section
    if current_section
      finalize_section(current_section)
      @sections << current_section
    end
  end

  def finalize_section(section)
    # Count non-empty content lines
    section[:content_line_count] = section[:lines].reject { |l| l.strip.empty? }.length
  end

  def generate_id(title)
    title
      .downcase
      .gsub(/[^a-z0-9\s-]/, '')
      .gsub(/\s+/, '-')
      .gsub(/-+/, '-')
      .gsub(/^-|-$/, '')
  end

  def suggest_filename(id)
    # Strip _{context} suffix
    clean_id = id.gsub(/_\{context\}$/, '')
    "#{clean_id}.adoc"
  end

  def suggest_content_type(title)
    title_lower = title.downcase
    if title_lower.match?(/\b(configur|install|creat|deploy|set up|setting up|enabl|disabl|remov|delet|upgrad|migrat|troubleshoot)\b/)
      'PROCEDURE'
    elsif title_lower.match?(/\b(parameter|option|field|variable|reference|table|list of|api|specification)\b/)
      'REFERENCE'
    else
      'CONCEPT'
    end
  end

  def create_module(section)
    modules_dir = File.join(File.dirname(@input_file), '..')
    # If we're already in a modules directory or similar, put new files alongside
    if File.basename(File.dirname(@input_file)) == 'modules'
      modules_dir = File.dirname(@input_file)
    else
      modules_dir = File.dirname(@input_file)
    end

    filepath = File.join(modules_dir, section[:suggested_filename])

    # Build module content
    content_lines = []
    content_lines << ":_mod-docs-content-type: #{section[:suggested_content_type]}"

    # Use the existing ID or generate one with context
    section_id = section[:id]
    section_id += "_{context}" unless section_id.include?('{context}')
    content_lines << "[id=\"#{section_id}\"]"
    content_lines << "= #{section[:title]}"
    content_lines << ""

    # Add the section content
    section_content = section[:lines].dup
    # Strip leading empty lines
    section_content.shift while section_content.first&.strip&.empty?
    # Strip trailing empty lines
    section_content.pop while section_content.last&.strip&.empty?

    content_lines.concat(section_content)
    content_lines << ""

    content = content_lines.join("\n")

    if @dry_run
      puts "Would create: #{filepath}"
      puts "  Title: #{section[:title]}"
      puts "  Content type: #{section[:suggested_content_type]}"
      puts "  Content lines: #{section[:content_line_count]}"
    else
      File.write(filepath, content)
      puts "Created: #{filepath}"
    end

    { path: filepath, section: section }
  end

  def update_original(lines)
    # Remove nested sections from original file
    # Find the line ranges to remove
    remove_ranges = []

    @sections.each do |section|
      start_line = section[:line_number]
      # Check if there's an ID line before the heading
      if start_line > 1 && lines[start_line - 2]&.match?(ID_PATTERN)
        start_line -= 1
      end

      # Find end: next section at same or higher level, or end of file
      end_line = lines.length
      found_end = false
      (section[:line_number]..lines.length - 1).each do |i|
        next if i == section[:line_number] - 1 # skip the heading itself
        if match = lines[i]&.match(HEADING_PATTERN)
          if match[1].length <= section[:level]
            end_line = i
            found_end = true
            break
          end
        end
      end

      remove_ranges << { start: start_line - 1, end: end_line - 1 }
    end

    # Remove ranges in reverse order to preserve line numbers
    new_lines = lines.dup
    remove_ranges.reverse.each do |range|
      new_lines.slice!(range[:start]..range[:end])
    end

    # Clean up multiple consecutive blank lines
    cleaned = []
    prev_blank = false
    new_lines.each do |line|
      if line.strip.empty?
        cleaned << line unless prev_blank
        prev_blank = true
      else
        cleaned << line
        prev_blank = false
      end
    end

    # Ensure file ends with newline
    cleaned << "" unless cleaned.last&.strip&.empty?

    content = cleaned.join("\n")

    if @dry_run
      puts ""
      puts "Would update: #{@input_file}"
      puts "  Removed #{@sections.length} nested section(s)"
    else
      File.write(@input_file, content)
      puts ""
      puts "Updated: #{@input_file}"
      puts "  Removed #{@sections.length} nested section(s)"
    end
  end

  def update_assembly(created_files)
    unless File.exist?(@assembly)
      puts "Assembly file not found: #{@assembly}"
      return
    end

    assembly_lines = File.readlines(@assembly, chomp: true)

    # Find the include line for the original module
    original_basename = File.basename(@input_file)
    include_index = nil
    include_leveloffset = nil

    assembly_lines.each_with_index do |line, index|
      if line.include?(original_basename)
        include_index = index
        if match = line.match(/leveloffset=\+(\d+)/)
          include_leveloffset = match[1].to_i
        end
        break
      end
    end

    unless include_index
      puts "Could not find include for #{original_basename} in #{@assembly}"
      return
    end

    # Insert new includes after the original module's include
    insert_lines = []
    created_files.each do |cf|
      section = cf[:section]
      # Calculate leveloffset relative to the original module
      relative_offset = (include_leveloffset || 1) + (section[:level] - @title_level)
      new_basename = File.basename(cf[:path])

      # Build the include path relative to the assembly
      # Determine the relative path from assembly to modules
      original_include = assembly_lines[include_index]
      if match = original_include.match(/^include::(.+?)#{Regexp.escape(original_basename)}/)
        prefix = match[1]
      else
        prefix = "modules/"
      end

      insert_lines << ""
      insert_lines << "include::#{prefix}#{new_basename}[leveloffset=+#{relative_offset}]"
    end

    # Insert after the original include line
    assembly_lines.insert(include_index + 1, *insert_lines)

    content = assembly_lines.join("\n") + "\n"

    if @dry_run
      puts ""
      puts "Would update assembly: #{@assembly}"
      insert_lines.each { |l| puts "  + #{l}" unless l.strip.empty? }
    else
      File.write(@assembly, content)
      puts ""
      puts "Updated assembly: #{@assembly}"
      insert_lines.each { |l| puts "  + #{l}" unless l.strip.empty? }
    end
  end

  def output_result(result)
    if @json
      puts JSON.pretty_generate(result)
    else
      puts "File: #{result[:file]}"
      puts "Content type: #{result[:content_type] || 'unknown'}"
      puts "Title: #{result[:title]}"

      if result[:message]
        puts result[:message]
        return
      end

      if result[:nested_sections].empty?
        puts "No nested sections found."
      else
        puts "Nested sections found: #{result[:nested_sections].length}"
        puts ""
        result[:nested_sections].each do |s|
          puts "  Line #{s[:line]}: #{s[:heading_markers]} #{s[:title]}"
          puts "    ID: #{s[:id]}"
          puts "    Content lines: #{s[:content_lines]}"
          puts "    Suggested filename: #{s[:suggested_filename]}"
          puts "    Suggested content type: #{s[:suggested_content_type]}"
          puts ""
        end
      end
    end
  end

  def error_result(message)
    if @json
      puts JSON.pretty_generate({ error: message })
    else
      puts "Error: #{message}"
    end
  end
end

# Command-line interface
if __FILE__ == $PROGRAM_NAME
  input_file = nil
  options = {}

  i = 0
  while i < ARGV.length
    arg = ARGV[i]
    case arg
    when '--dry-run', '-n'
      options[:dry_run] = true
      i += 1
    when '--json'
      options[:json] = true
      i += 1
    when '--assembly', '-a'
      if i + 1 < ARGV.length
        options[:assembly] = ARGV[i + 1]
        i += 2
      else
        puts "Error: --assembly requires an argument"
        exit 1
      end
    when '--split'
      options[:split] = true
      i += 1
    when '--help', '-h'
      puts <<~HELP
        Usage: ruby split_nested_section.rb <file.adoc> [options]

        Detect and optionally split nested sections in AsciiDoc module files.

        Options:
          --dry-run, -n      Show what would be done without writing files
          --json             Output analysis as JSON
          --split            Split nested sections into separate files
          --assembly, -a FILE  Parent assembly file to update with new includes
          -h, --help         Show this help message

        Examples:
          # Analyze a module for nested sections
          ruby split_nested_section.rb modules/nw-ptp-introduction.adoc

          # Analyze with JSON output
          ruby split_nested_section.rb modules/nw-ptp-introduction.adoc --json

          # Split nested sections (dry run)
          ruby split_nested_section.rb modules/nw-ptp-introduction.adoc --split --dry-run

          # Split and update assembly
          ruby split_nested_section.rb modules/nw-ptp-introduction.adoc --split --assembly about-ptp.adoc
      HELP
      exit 0
    else
      input_file = arg
      i += 1
    end
  end

  if input_file.nil?
    puts "Error: No input file specified"
    puts "Usage: ruby split_nested_section.rb <file.adoc> [options]"
    exit 1
  end

  tool = SplitNestedSection.new(input_file, options)

  if options[:split]
    tool.split
  else
    tool.analyze
  end
end
