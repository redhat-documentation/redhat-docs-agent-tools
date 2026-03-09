# DITA Concept generator
# Converts AsciiDoc CONCEPT modules to DITA concept topics

require_relative '../dita_generator'
require_relative '../content_tracker'

class ConceptGenerator
  include DITAGenerator

  def initialize(doc, ast, tracker = nil)
    @doc = doc
    @ast = ast
    @tracker = tracker
  end

  def generate
    id = @doc.id || DITAGenerator.generate_id(@doc.title)
    title = @doc.title || 'Untitled'
    shortdesc = extract_shortdesc

    xml = []
    xml << DITAGenerator.xml_declaration
    xml << DITAGenerator::DOCTYPES[:concept]
    xml << "<concept id=\"#{id}\">"
    xml << "  <title>#{DITAGenerator.convert_inline(title)}</title>"
    xml << "  <shortdesc>#{DITAGenerator.convert_inline(shortdesc)}</shortdesc>" if shortdesc
    xml << "  <conbody>"
    xml << generate_body_content
    xml << "  </conbody>"
    xml << "</concept>"
    xml.join("\n")
  end

  private

  def track(node)
    @tracker&.mark_processed(node)
  end

  def extract_shortdesc
    # Look for [role="_abstract"] paragraph
    @doc.blocks.each do |block|
      if block.node_name == 'paragraph' && block.roles&.include?('_abstract')
        track(block)
        return block.lines.join(' ')
      end
    end
    # Fallback to first paragraph
    @doc.blocks.each do |block|
      if block.node_name == 'paragraph'
        track(block)
        return block.lines.join(' ')
      end
    end
    nil
  end

  def generate_body_content
    content = []
    skip_first_para = true

    @doc.blocks.each do |block|
      # Skip the abstract paragraph (already tracked in extract_shortdesc)
      if skip_first_para && block.node_name == 'paragraph'
        if block.roles&.include?('_abstract')
          skip_first_para = false
          next
        end
      end

      content << convert_block(block, 4)
    end

    content.compact.join("\n")
  end

  def convert_block(block, indent)
    spaces = ' ' * indent
    result = case block.node_name
    when 'paragraph'
      return nil if block.roles&.include?('_abstract')
      "#{spaces}<p>#{DITAGenerator.convert_inline(block.lines.join(' '))}</p>"
    when 'ulist'
      items = block.blocks.map do |item|
        convert_list_item(item, indent + 2)
      end
      "#{spaces}<ul>\n#{items.join("\n")}\n#{spaces}</ul>"
    when 'olist'
      items = block.blocks.map do |item|
        convert_list_item(item, indent + 2)
      end
      "#{spaces}<ol>\n#{items.join("\n")}\n#{spaces}</ol>"
    when 'dlist'
      entries = []
      # Definition lists use .items which returns arrays of [terms, description]
      if block.respond_to?(:items) && block.items
        block.items.each do |item|
          terms, desc = item
          term_text = terms.is_a?(Array) ? (terms.first&.text rescue terms.first.to_s) : (terms.text rescue terms.to_s)
          desc_text = desc&.text rescue desc.to_s
          entries << "#{spaces}  <dlentry>"
          entries << "#{spaces}    <dt>#{DITAGenerator.convert_inline(term_text)}</dt>"
          entries << "#{spaces}    <dd>#{DITAGenerator.convert_inline(desc_text)}</dd>"
          entries << "#{spaces}  </dlentry>"
        end
      end
      "#{spaces}<dl>\n#{entries.join("\n")}\n#{spaces}</dl>" unless entries.empty?
    when 'listing', 'literal'
      lang = block.attributes['language'] || 'text'
      code = DITAGenerator.escape_xml(block.lines.join("\n"))
      "#{spaces}<codeblock outputclass=\"language-#{lang}\">\n#{code}\n#{spaces}</codeblock>"
    when 'table'
      generate_table(block, indent)
    when 'section'
      section_content = []
      section_content << "#{spaces}<section>"
      section_content << "#{spaces}  <title>#{DITAGenerator.convert_inline(block.title)}</title>" if block.title
      block.blocks.each do |child|
        section_content << convert_block(child, indent + 2)
      end
      section_content << "#{spaces}</section>"
      section_content.compact.join("\n")
    when 'admonition'
      # Handle NOTE, WARNING, IMPORTANT, etc.
      admon_type = block.attributes['name'] || 'note'
      note_content = []
      note_content << "#{spaces}<note type=\"#{admon_type}\">"
      # Admonition content is in blocks, not lines
      if block.respond_to?(:blocks) && !block.blocks.empty?
        block.blocks.each do |child|
          child_content = convert_block(child, indent + 2)
          note_content << child_content if child_content
        end
      elsif block.lines && !block.lines.empty?
        note_content << "#{spaces}  <p>#{DITAGenerator.convert_inline(block.lines.join(' '))}</p>"
      end
      note_content << "#{spaces}</note>"
      note_content.join("\n")
    when 'colist'
      # Callout list - annotations for code blocks (e.g., <1>, <2>)
      # Convert to ordered list in DITA
      items = []
      if block.respond_to?(:blocks) && !block.blocks.empty?
        block.blocks.each do |item|
          item_text = item.text || ''
          items << "#{spaces}  <li>#{DITAGenerator.convert_inline(item_text)}</li>"
          track(item)
        end
      elsif block.respond_to?(:items) && block.items
        block.items.each do |item|
          item_text = item.respond_to?(:text) ? item.text : item.to_s
          items << "#{spaces}  <li>#{DITAGenerator.convert_inline(item_text)}</li>"
        end
      end
      "#{spaces}<ol>\n#{items.join("\n")}\n#{spaces}</ol>" unless items.empty?
    when 'open'
      # Open block - container for grouping content
      # Process each child block
      open_content = []
      if block.respond_to?(:blocks) && !block.blocks.empty?
        block.blocks.each do |child|
          child_content = convert_block(child, indent)
          open_content << child_content if child_content
        end
      end
      open_content.join("\n") unless open_content.empty?
    else
      # Emit UNHANDLED comment for unsupported element types
      comment = ContentTracker.generate_unhandled_comment(block,
        parent_type: 'conbody', parent_title: @doc.title, position: nil)
      track(block)
      comment
    end

    # Track this block if it produced output
    track(block) if result
    result
  end

  # Convert a list item, including any nested blocks (code blocks, paragraphs, sublists)
  def convert_list_item(item, indent)
    spaces = ' ' * indent
    content = []
    content << "#{spaces}<li>"

    # Add the main text of the list item
    if item.text && !item.text.empty?
      content << "#{spaces}  <p>#{DITAGenerator.convert_inline(item.text)}</p>"
    end

    # Process any nested blocks (code blocks, paragraphs, sublists, etc.)
    if item.respond_to?(:blocks) && !item.blocks.empty?
      item.blocks.each do |child|
        child_content = convert_block(child, indent + 2)
        content << child_content if child_content
      end
    end

    content << "#{spaces}</li>"
    track(item)
    content.join("\n")
  end

  def generate_table(block, indent)
    spaces = ' ' * indent
    rows = block.rows
    return nil if rows.nil?

    table_xml = []
    table_xml << "#{spaces}<table>"

    # Header row
    if rows[:head] && !rows[:head].empty?
      table_xml << "#{spaces}  <tgroup cols=\"#{rows[:head].first.size}\">"
      table_xml << "#{spaces}    <thead>"
      rows[:head].each do |row|
        table_xml << "#{spaces}      <row>"
        row.each do |cell|
          table_xml << "#{spaces}        <entry>#{DITAGenerator.convert_inline(cell.text)}</entry>"
        end
        table_xml << "#{spaces}      </row>"
      end
      table_xml << "#{spaces}    </thead>"
    else
      cols = rows[:body]&.first&.size || 1
      table_xml << "#{spaces}  <tgroup cols=\"#{cols}\">"
    end

    # Body rows
    if rows[:body] && !rows[:body].empty?
      table_xml << "#{spaces}    <tbody>"
      rows[:body].each do |row|
        table_xml << "#{spaces}      <row>"
        row.each do |cell|
          table_xml << "#{spaces}        <entry>#{DITAGenerator.convert_inline(cell.text)}</entry>"
        end
        table_xml << "#{spaces}      </row>"
      end
      table_xml << "#{spaces}    </tbody>"
    end

    table_xml << "#{spaces}  </tgroup>"
    table_xml << "#{spaces}</table>"
    table_xml.join("\n")
  end
end
