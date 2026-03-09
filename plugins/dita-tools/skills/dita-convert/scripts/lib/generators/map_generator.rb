# DITA Map generator (for assemblies)
# Converts AsciiDoc ASSEMBLY files to DITA maps

require_relative '../dita_generator'
require_relative '../content_tracker'

class MapGenerator
  include DITAGenerator

  def initialize(doc, ast, base_dir, tracker = nil)
    @doc = doc
    @ast = ast
    @base_dir = base_dir
    @tracker = tracker
  end

  def track(node)
    @tracker&.mark_processed(node)
  end

  # Recursively mark all nodes as processed (for assemblies where content is in includes)
  def track_all(node)
    return unless node.respond_to?(:node_name)
    track(node)
    if node.respond_to?(:blocks) && node.blocks
      node.blocks.each { |child| track_all(child) }
    end
  end

  def generate
    id = @doc.id || DITAGenerator.generate_id(@doc.title)
    title = @doc.title || 'Untitled'

    xml = []
    xml << DITAGenerator.xml_declaration
    xml << DITAGenerator::DOCTYPES[:map]
    xml << "<map id=\"#{id}\">"
    xml << "  <title>#{DITAGenerator.convert_inline(title)}</title>"

    # Extract includes and generate topicrefs
    @doc.blocks.each do |block|
      if block.node_name == 'paragraph' && block.roles&.include?('_abstract')
        xml << "  <topicmeta>"
        xml << "    <shortdesc>#{DITAGenerator.convert_inline(block.lines.join(' '))}</shortdesc>"
        xml << "  </topicmeta>"
        track(block)
      end
    end

    # Find include directives by parsing the source
    includes = extract_includes
    includes.each do |inc|
      href = inc[:href].sub(/\.adoc$/, '.dita')
      xml << "  <topicref href=\"#{href}\"/>"
    end

    # Mark all blocks as processed for assemblies (content is in includes, converted separately)
    @doc.blocks.each { |block| track_all(block) }

    xml << "</map>"
    xml.join("\n")
  end

  def extract_includes
    includes = []
    source = File.read(@doc.attributes['docfile']) rescue ''

    source.scan(/include::([^\[]+)\[([^\]]*)\]/) do |path, attrs|
      # Skip attribute includes (common patterns: _attributes/, attributes.adoc)
      next if path.include?('_attributes/') || path.match?(/^_?attributes/)
      # Skip snippet includes
      next if path.include?('snippets/')
      includes << { href: path, attrs: attrs }
    end

    includes
  end

  # Generate map with topicrefs pointing to topics/ folder
  def generate_with_topics_folder
    id = @doc.id || DITAGenerator.generate_id(@doc.title)
    title = @doc.title || 'Untitled'

    xml = []
    xml << DITAGenerator.xml_declaration
    xml << DITAGenerator::DOCTYPES[:map]
    xml << "<map id=\"#{id}\">"
    xml << "  <title>#{DITAGenerator.convert_inline(title)}</title>"

    # Extract shortdesc from abstract
    @doc.blocks.each do |block|
      if block.node_name == 'paragraph' && block.roles&.include?('_abstract')
        xml << "  <topicmeta>"
        xml << "    <shortdesc>#{DITAGenerator.convert_inline(block.lines.join(' '))}</shortdesc>"
        xml << "  </topicmeta>"
        track(block)
        break
      end
    end

    # Find include directives and generate topicrefs pointing to topics/ folder
    includes = extract_includes
    includes.each do |inc|
      # Extract just the filename without path
      basename = File.basename(inc[:href], '.adoc')
      href = "topics/#{basename}.dita"
      xml << "  <topicref href=\"#{href}\"/>"
    end

    # Mark all blocks as processed for assemblies (content is in includes, converted separately)
    @doc.blocks.each { |block| track_all(block) }

    xml << "</map>"
    xml.join("\n")
  end
end
