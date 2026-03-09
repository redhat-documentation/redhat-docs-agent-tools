# Main DITA Converter class
# Orchestrates the conversion of AsciiDoc files to DITA format

require 'asciidoctor'
require 'json'
require 'fileutils'

require_relative 'ast_converter'
require_relative 'content_tracker'
require_relative 'dita_validator'
require_relative 'generators/concept_generator'
require_relative 'generators/task_generator'
require_relative 'generators/reference_generator'
require_relative 'generators/map_generator'

# Check for optional toon gem
begin
  require 'toon'
  TOON_AVAILABLE = true
rescue LoadError
  TOON_AVAILABLE = false
end

class DITAConverter
  def initialize(input_file, options = {})
    @input_file = input_file
    @output_dir = options[:output_dir] || File.dirname(input_file)
    @dry_run = options[:dry_run] || false
    @show_ast = options[:show_ast] || false
  end

  def convert
    # Load and parse AsciiDoc
    @doc = Asciidoctor.load_file(
      @input_file,
      safe: :safe,
      parse: true,
      base_dir: File.dirname(@input_file),
      attributes: {
        'attribute-missing' => 'drop',
        'attribute-undefined' => 'drop'
      }
    )

    # Generate AST with node map for in-place unhandled marking
    @ast, @ast_node_map = ASTConverter.node_to_hash_with_map(@doc)

    # Create content tracker with AST node map
    @tracker = ContentTracker.new(@ast_node_map)
    @tracker.register_document(@doc)

    # Detect content type
    content_type = detect_content_type

    # Generate appropriate DITA output
    result = case content_type
             when :assembly
               convert_assembly
             when :concept
               convert_concept
             when :procedure
               convert_task
             when :reference
               convert_reference
             when :snippet
               # Snippets are included inline where referenced - no standalone output needed
               { type: :snippet, input: @input_file, included_inline: true }
             else
               { error: "Unknown content type" }
             end

    # Mark unhandled elements directly in AST at their location and add coverage summary
    unless content_type == :snippet
      # Mark unhandled elements in-place in the AST
      @tracker.mark_unhandled_in_ast

      # Also keep the top-level summary for easy reference
      unhandled = @tracker.unhandled_elements
      @ast[:unhandled_summary] = {
        count: unhandled.length,
        elements: unhandled.map { |e| { type: e[:type], path: e[:path] } }
      } unless unhandled.empty?

      @ast[:coverage] = {
        total_nodes: @tracker.coverage_report[:total_nodes],
        processed_nodes: @tracker.coverage_report[:processed_nodes],
        coverage_percent: @tracker.coverage_report[:coverage_percent]
      }
    end

    # Write AST to output folder (after conversion so it includes unhandled info)
    write_ast_file

    # Show AST to console if requested
    if @show_ast
      # Clean up internal keys before display
      display_ast = ASTConverter.clean_ast(@ast)
      json = JSON.pretty_generate(display_ast)
      if TOON_AVAILABLE
        begin
          puts "=== TOON Format AST ==="
          puts Toon.encode(display_ast)
        rescue
          puts "=== JSON AST ==="
          puts json
        end
      else
        puts "=== JSON AST ==="
        puts json
      end
      puts ""
    end

    # Print content coverage warnings
    @tracker.print_warnings unless content_type == :snippet

    result
  end

  private

  # Detect content type from the raw source file
  # We read from the source file directly because included files (like _attributes/attributes.adoc)
  # can override the :_mod-docs-content-type: attribute after Asciidoctor processes includes.
  # Valid AsciiDoc values: CONCEPT, REFERENCE, PROCEDURE, ASSEMBLY, SNIPPET
  # PROCEDURE maps to DITA Task topic type
  def detect_content_type
    detect_content_type_from_file(@input_file)
  end

  # Helper to detect content type from a file by reading the raw source
  def detect_content_type_from_file(file_path)
    content_type = nil

    # Read the first 50 lines of the file to find the content type attribute
    File.open(file_path, 'r') do |f|
      50.times do
        line = f.gets
        break if line.nil?

        # Match :_mod-docs-content-type: VALUE pattern
        if line =~ /^:_mod-docs-content-type:\s*(\S+)/i
          content_type = $1.strip
          break
        end
      end
    end

    if content_type.nil?
      raise "ERROR: Missing required attribute ':_mod-docs-content-type:' in #{file_path}. " \
            "Valid values are: CONCEPT, REFERENCE, PROCEDURE, ASSEMBLY"
    end

    parse_content_type(content_type, file_path)
  end

  # Parse and validate content type string
  def parse_content_type(content_type, file_path)
    case content_type.upcase
    when 'ASSEMBLY'
      :assembly
    when 'CONCEPT'
      :concept
    when 'PROCEDURE'
      :procedure  # Maps to DITA Task
    when 'REFERENCE'
      :reference
    when 'SNIPPET'
      :snippet  # Included inline where referenced, no standalone conversion
    else
      raise "ERROR: Invalid ':_mod-docs-content-type:' value '#{content_type}' in #{file_path}. " \
            "Valid values are: CONCEPT, REFERENCE, PROCEDURE, ASSEMBLY, SNIPPET"
    end
  end

  def convert_assembly
    generator = MapGenerator.new(@doc, @ast, File.dirname(@input_file), @tracker)

    # Use the new generator that puts topicrefs in topics/ folder
    xml = generator.generate_with_topics_folder

    output_file = output_path('.ditamap')

    write_output(output_file, xml)

    unless @dry_run
      validator = DITAValidator.new(@output_dir)
      validation = validator.validate(output_file)
      puts "Validation: #{validation[:message]}"
    end

    # Convert included modules and put them in topics/ subfolder
    includes = generator.extract_includes
    module_results = []
    topics_dir = File.join(@output_dir, 'topics')

    includes.each do |inc|
      module_path = File.join(File.dirname(@input_file), inc[:href])
      if File.exist?(module_path)
        # Convert each module with output going to topics/ subfolder
        converter = DITAConverter.new(module_path, {
          output_dir: topics_dir,
          dry_run: @dry_run
        })
        module_results << converter.convert
      else
        puts "Warning: Module not found: #{module_path}"
      end
    end

    {
      type: :assembly,
      input: @input_file,
      output: output_file,
      topics_dir: topics_dir,
      modules: module_results
    }
  end

  def convert_concept
    generator = ConceptGenerator.new(@doc, @ast, @tracker)
    xml = generator.generate

    output_file = output_path('.dita')

    write_output(output_file, xml)

    unless @dry_run
      validator = DITAValidator.new(@output_dir)
      validation = validator.validate(output_file)
      puts "Validation: #{validation[:message]}"
    end

    {
      type: :concept,
      input: @input_file,
      output: output_file
    }
  end

  def convert_task
    generator = TaskGenerator.new(@doc, @ast, @tracker)
    xml = generator.generate

    output_file = output_path('.dita')

    write_output(output_file, xml)

    unless @dry_run
      validator = DITAValidator.new(@output_dir)
      validation = validator.validate(output_file)
      puts "Validation: #{validation[:message]}"
    end

    {
      type: :task,
      input: @input_file,
      output: output_file
    }
  end

  def convert_reference
    generator = ReferenceGenerator.new(@doc, @ast, @tracker)
    xml = generator.generate

    output_file = output_path('.dita')

    write_output(output_file, xml)

    unless @dry_run
      validator = DITAValidator.new(@output_dir)
      validation = validator.validate(output_file)
      puts "Validation: #{validation[:message]}"
    end

    {
      type: :reference,
      input: @input_file,
      output: output_file
    }
  end

  def write_ast_file
    basename = File.basename(@input_file, '.adoc')

    # Clean up internal _object_id keys before serialization
    cleaned_ast = ASTConverter.clean_ast(@ast)

    if TOON_AVAILABLE
      begin
        ast_content = Toon.encode(cleaned_ast)
        ast_file = File.join(@output_dir, "#{basename}.ast.toon")
      rescue
        ast_content = JSON.pretty_generate(cleaned_ast)
        ast_file = File.join(@output_dir, "#{basename}.ast.json")
      end
    else
      ast_content = JSON.pretty_generate(cleaned_ast)
      ast_file = File.join(@output_dir, "#{basename}.ast.json")
    end

    write_output(ast_file, ast_content)
  end

  def output_path(extension)
    basename = File.basename(@input_file, '.adoc')
    File.join(@output_dir, basename + extension)
  end

  def write_output(path, content)
    if @dry_run
      puts "Would write to: #{path}"
      puts "---"
      puts content
      puts "---"
    else
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
      puts "Wrote: #{path}"
    end
  end
end
