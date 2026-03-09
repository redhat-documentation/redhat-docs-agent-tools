# DITA Reference generator
# Converts AsciiDoc REFERENCE modules to DITA reference topics

require_relative '../dita_generator'
require_relative '../content_tracker'

class ReferenceGenerator
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
    xml << DITAGenerator::DOCTYPES[:reference]
    xml << "<reference id=\"#{id}\">"
    xml << "  <title>#{DITAGenerator.convert_inline(title)}</title>"
    xml << "  <shortdesc>#{DITAGenerator.convert_inline(shortdesc)}</shortdesc>" if shortdesc
    xml << "  <refbody>"
    xml << generate_refbody
    xml << "  </refbody>"
    xml << "</reference>"
    xml.join("\n")
  end

  private

  def track(node)
    @tracker&.mark_processed(node)
  end

  def extract_shortdesc
    @doc.blocks.each do |block|
      if block.node_name == 'paragraph' && block.roles&.include?('_abstract')
        track(block)
        return block.lines.join(' ')
      end
    end
    nil
  end

  def generate_refbody
    content = []

    @doc.blocks.each do |block|
      # Skip abstract (already tracked in extract_shortdesc)
      next if block.node_name == 'paragraph' && block.roles&.include?('_abstract')

      case block.node_name
      when 'table'
        content << generate_table(block, 4)
        track(block)
      when 'dlist'
        content << generate_properties(block, 4)
        track(block)
      when 'section'
        content << generate_section(block, 4)
        track(block)
      when 'paragraph'
        if block.title
          content << "    <section>"
          content << "      <title>#{DITAGenerator.convert_inline(block.title)}</title>"
          content << "      <p>#{DITAGenerator.convert_inline(block.lines.join(' '))}</p>"
          content << "    </section>"
        else
          # Regular paragraphs without titles
          content << "    <section>"
          content << "      <p>#{DITAGenerator.convert_inline(block.lines.join(' '))}</p>"
          content << "    </section>"
        end
        track(block)
      when 'listing', 'literal'
        # Code blocks at document level
        lang = block.attributes['language'] || 'text'
        code = DITAGenerator.escape_xml(block.lines.join("\n"))
        content << "    <section>"
        content << "      <title>#{DITAGenerator.convert_inline(block.title)}</title>" if block.title
        content << "      <codeblock outputclass=\"language-#{lang}\">"
        content << code
        content << "      </codeblock>"
        content << "    </section>"
        track(block)
      when 'admonition'
        # Notes at document level
        admon_type = block.attributes['name'] || 'note'
        content << "    <section>"
        content << "      <note type=\"#{admon_type}\">"
        if block.respond_to?(:blocks) && !block.blocks.empty?
          block.blocks.each do |child|
            if child.node_name == 'paragraph'
              content << "        <p>#{DITAGenerator.convert_inline(child.lines.join(' '))}</p>"
              track(child)
            end
          end
        elsif block.lines && !block.lines.empty?
          content << "        <p>#{DITAGenerator.convert_inline(block.lines.join(' '))}</p>"
        end
        content << "      </note>"
        content << "    </section>"
        track(block)
      when 'ulist'
        content << "    <section>"
        content << "      <title>#{DITAGenerator.convert_inline(block.title)}</title>" if block.title
        content << "      <ul>"
        block.blocks.each do |item|
          content << "        <li>#{DITAGenerator.convert_inline(item.text || '')}</li>"
          track(item)
        end
        content << "      </ul>"
        content << "    </section>"
        track(block)
      when 'olist'
        content << "    <section>"
        content << "      <title>#{DITAGenerator.convert_inline(block.title)}</title>" if block.title
        content << "      <ol>"
        block.blocks.each do |item|
          content << "        <li>#{DITAGenerator.convert_inline(item.text || '')}</li>"
          track(item)
        end
        content << "      </ol>"
        content << "    </section>"
        track(block)
      when 'colist'
        content << "    <section>"
        content << "      <ol>"
        if block.respond_to?(:blocks) && !block.blocks.empty?
          block.blocks.each do |coitem|
            content << "        <li>#{DITAGenerator.convert_inline(coitem.text || '')}</li>"
            track(coitem)
          end
        end
        content << "      </ol>"
        content << "    </section>"
        track(block)
      when 'open'
        # Open block - process children
        if block.respond_to?(:blocks) && !block.blocks.empty?
          block.blocks.each do |child|
            case child.node_name
            when 'paragraph'
              content << "    <section>"
              content << "      <p>#{DITAGenerator.convert_inline(child.lines.join(' '))}</p>"
              content << "    </section>"
              track(child)
            when 'listing', 'literal'
              lang = child.attributes['language'] || 'text'
              code = DITAGenerator.escape_xml(child.lines.join("\n"))
              content << "    <section>"
              content << "      <codeblock outputclass=\"language-#{lang}\">"
              content << code
              content << "      </codeblock>"
              content << "    </section>"
              track(child)
            end
          end
        end
        track(block)
      end
    end

    content.compact.join("\n")
  end

  def generate_table(block, indent)
    spaces = ' ' * indent
    rows = block.rows
    return nil if rows.nil?

    table_xml = []

    # Add section with title if table has one
    if block.title
      table_xml << "#{spaces}<section>"
      table_xml << "#{spaces}  <title>#{DITAGenerator.convert_inline(block.title)}</title>"
      indent += 2
      spaces = ' ' * indent
    end

    table_xml << "#{spaces}<table>"

    # Determine column count
    col_count = rows[:head]&.first&.size || rows[:body]&.first&.size || 1
    table_xml << "#{spaces}  <tgroup cols=\"#{col_count}\">"

    # Header row
    if rows[:head] && !rows[:head].empty?
      table_xml << "#{spaces}    <thead>"
      rows[:head].each do |row|
        table_xml << "#{spaces}      <row>"
        row.each do |cell|
          table_xml << "#{spaces}        <entry>#{DITAGenerator.convert_inline(cell.text)}</entry>"
        end
        table_xml << "#{spaces}      </row>"
      end
      table_xml << "#{spaces}    </thead>"
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

    if block.title
      table_xml << "#{' ' * (indent - 2)}</section>"
    end

    table_xml.join("\n")
  end

  def generate_properties(block, indent)
    spaces = ' ' * indent
    props = []
    props << "#{spaces}<properties>"

    block.items.each do |item|
      terms = item[0]
      desc = item[1]
      term_text = terms.is_a?(Array) ? terms.first&.text : terms.text rescue terms.to_s
      desc_text = desc&.text rescue desc.to_s

      props << "#{spaces}  <property>"
      props << "#{spaces}    <propvalue>#{DITAGenerator.convert_inline(term_text)}</propvalue>"
      props << "#{spaces}    <propdesc>#{DITAGenerator.convert_inline(desc_text)}</propdesc>"
      props << "#{spaces}  </property>"
    end

    props << "#{spaces}</properties>"
    props.join("\n")
  rescue
    nil
  end

  def generate_section(block, indent)
    spaces = ' ' * indent
    section = []
    section << "#{spaces}<section>"
    section << "#{spaces}  <title>#{DITAGenerator.convert_inline(block.title)}</title>" if block.title

    block.blocks.each do |child|
      case child.node_name
      when 'paragraph'
        section << "#{spaces}  <p>#{DITAGenerator.convert_inline(child.lines.join(' '))}</p>"
        track(child)
      when 'table'
        section << generate_table(child, indent + 2)
        track(child)
      when 'dlist'
        section << generate_properties(child, indent + 2)
        track(child)
      when 'listing', 'literal'
        lang = child.attributes['language'] || 'text'
        code = DITAGenerator.escape_xml(child.lines.join("\n"))
        section << "#{spaces}  <codeblock outputclass=\"language-#{lang}\">"
        section << code
        section << "#{spaces}  </codeblock>"
        track(child)
      when 'ulist'
        section << "#{spaces}  <ul>"
        child.blocks.each_with_index do |item, item_idx|
          # Handle nested content in list items (e.g., code blocks, admonitions)
          if item.respond_to?(:blocks) && !item.blocks.empty?
            section << "#{spaces}    <li>"
            section << "#{spaces}      <p>#{DITAGenerator.convert_inline(item.text || '')}</p>" if item.text && !item.text.empty?
            item.blocks.each_with_index do |nested, nested_idx|
              emit_list_item_child(section, nested, spaces, block.title, item_idx, nested_idx)
            end
            section << "#{spaces}    </li>"
          else
            section << "#{spaces}    <li>#{DITAGenerator.convert_inline(item.text || '')}</li>"
          end
          track(item)
        end
        section << "#{spaces}  </ul>"
        track(child)
      when 'olist'
        section << "#{spaces}  <ol>"
        child.blocks.each_with_index do |item, item_idx|
          # Handle nested content in list items
          if item.respond_to?(:blocks) && !item.blocks.empty?
            section << "#{spaces}    <li>"
            section << "#{spaces}      <p>#{DITAGenerator.convert_inline(item.text || '')}</p>" if item.text && !item.text.empty?
            item.blocks.each_with_index do |nested, nested_idx|
              emit_list_item_child(section, nested, spaces, block.title, item_idx, nested_idx)
            end
            section << "#{spaces}    </li>"
          else
            section << "#{spaces}    <li>#{DITAGenerator.convert_inline(item.text || '')}</li>"
          end
          track(item)
        end
        section << "#{spaces}  </ol>"
        track(child)
      when 'admonition'
        admon_type = child.attributes['name'] || 'note'
        section << "#{spaces}  <note type=\"#{admon_type}\">"
        if child.respond_to?(:blocks) && !child.blocks.empty?
          child.blocks.each do |admon_child|
            if admon_child.node_name == 'paragraph'
              section << "#{spaces}    <p>#{DITAGenerator.convert_inline(admon_child.lines.join(' '))}</p>"
              track(admon_child)
            end
          end
        elsif child.lines && !child.lines.empty?
          section << "#{spaces}    <p>#{DITAGenerator.convert_inline(child.lines.join(' '))}</p>"
        end
        section << "#{spaces}  </note>"
        track(child)
      when 'colist'
        section << "#{spaces}  <ol>"
        if child.respond_to?(:blocks) && !child.blocks.empty?
          child.blocks.each do |coitem|
            section << "#{spaces}    <li>#{DITAGenerator.convert_inline(coitem.text || '')}</li>"
            track(coitem)
          end
        end
        section << "#{spaces}  </ol>"
        track(child)
      when 'section'
        # Nested section - flatten into current section as subsection content
        if child.title
          section << "#{spaces}  <p><b>#{DITAGenerator.convert_inline(child.title)}</b></p>"
        end
        child.blocks.each do |nested_child|
          case nested_child.node_name
          when 'paragraph'
            section << "#{spaces}  <p>#{DITAGenerator.convert_inline(nested_child.lines.join(' '))}</p>"
            track(nested_child)
          when 'table'
            section << generate_table(nested_child, indent + 2)
            track(nested_child)
          when 'ulist'
            section << "#{spaces}  <ul>"
            nested_child.blocks.each do |item|
              section << "#{spaces}    <li>#{DITAGenerator.convert_inline(item.text || '')}</li>"
              track(item)
            end
            section << "#{spaces}  </ul>"
            track(nested_child)
          when 'listing', 'literal'
            lang = nested_child.attributes['language'] || 'text'
            code = DITAGenerator.escape_xml(nested_child.lines.join("\n"))
            section << "#{spaces}  <codeblock outputclass=\"language-#{lang}\">"
            section << code
            section << "#{spaces}  </codeblock>"
            track(nested_child)
          end
        end
        track(child)
      when 'open'
        # Open block - process children inline
        if child.respond_to?(:blocks) && !child.blocks.empty?
          child.blocks.each do |open_child|
            case open_child.node_name
            when 'paragraph'
              section << "#{spaces}  <p>#{DITAGenerator.convert_inline(open_child.lines.join(' '))}</p>"
              track(open_child)
            when 'listing', 'literal'
              lang = open_child.attributes['language'] || 'text'
              code = DITAGenerator.escape_xml(open_child.lines.join("\n"))
              section << "#{spaces}  <codeblock outputclass=\"language-#{lang}\">"
              section << code
              section << "#{spaces}  </codeblock>"
              track(open_child)
            end
          end
        end
        track(child)
      end
    end

    section << "#{spaces}</section>"
    section.join("\n")
  end

  # Emit child content from a list item, or UNHANDLED comment if not supported
  def emit_list_item_child(output, child, spaces, parent_title, item_idx, child_idx)
    case child.node_name
    when 'listing', 'literal'
      lang = child.attributes['language'] || 'text'
      code = DITAGenerator.escape_xml(child.lines.join("\n"))
      output << "#{spaces}    <codeblock outputclass=\"language-#{lang}\">"
      output << code
      output << "#{spaces}    </codeblock>"
      track(child)
    when 'paragraph'
      output << "#{spaces}    <p>#{DITAGenerator.convert_inline(child.lines.join(' '))}</p>"
      track(child)
    when 'admonition'
      admon_type = child.attributes['name'] || 'note'
      output << "#{spaces}    <note type=\"#{admon_type}\">"
      if child.respond_to?(:blocks) && !child.blocks.empty?
        child.blocks.each do |admon_child|
          if admon_child.node_name == 'paragraph'
            output << "#{spaces}      <p>#{DITAGenerator.convert_inline(admon_child.lines.join(' '))}</p>"
            track(admon_child)
          end
        end
      elsif child.lines && !child.lines.empty?
        output << "#{spaces}      <p>#{DITAGenerator.convert_inline(child.lines.join(' '))}</p>"
      end
      output << "#{spaces}    </note>"
      track(child)
    else
      # Emit UNHANDLED comment for unsupported element types
      comment = ContentTracker.generate_unhandled_comment(child,
        parent_type: 'list_item', parent_title: parent_title, position: child_idx)
      output << comment if comment
      track(child)
    end
  end
end
