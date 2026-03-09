# DITA Task generator
# Converts AsciiDoc PROCEDURE modules to DITA task topics

require_relative '../dita_generator'
require_relative '../content_tracker'

class TaskGenerator
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
    xml << DITAGenerator::DOCTYPES[:task]
    xml << "<task id=\"#{id}\">"
    xml << "  <title>#{DITAGenerator.convert_inline(title)}</title>"
    xml << "  <shortdesc>#{DITAGenerator.convert_inline(shortdesc)}</shortdesc>" if shortdesc
    xml << "  <taskbody>"
    xml << generate_taskbody
    xml << "  </taskbody>"
    xml << "</task>"
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

  def generate_taskbody
    # Collect elements in separate buckets to ensure correct DITA ordering:
    # prereq?, context?, (steps|steps-unordered)?, result?, tasktroubleshooting?, example?, postreq?
    prereq_content = nil
    context_content = []
    steps_content = nil
    postreq_content = []

    # Track current section to properly assign content
    current_section = :context  # :context, :verification, :additional_resources

    @doc.blocks.each do |block|
      # Skip abstract (already tracked in extract_shortdesc)
      next if block.node_name == 'paragraph' && block.roles&.include?('_abstract')

      # Detect sections by title
      if block.title
        title_lower = block.title.downcase
        if title_lower.include?('prerequisite')
          prereq_content = generate_prereq_from_block(block)
          track(block)
          current_section = :context
          next
        elsif title_lower.include?('procedure')
          steps_content = generate_steps_from_block(block)
          track(block)
          current_section = :context
          next
        elsif title_lower.include?('verification')
          # Switch to verification mode - following blocks go to postreq
          current_section = :verification
          # If the block itself has content (e.g., a titled paragraph), add it
          if block.node_name == 'paragraph' && block.lines && !block.lines.empty?
            postreq_content << "      <p>#{DITAGenerator.convert_inline(block.lines.join(' '))}</p>"
          elsif block.respond_to?(:blocks) && !block.blocks.empty?
            generate_postreq_content(block, postreq_content)
          end
          track(block)
          next
        elsif title_lower.include?('additional') && title_lower.include?('resource')
          # Additional resources - skip for now (could map to related-links)
          current_section = :additional_resources
          track(block)
          next
        end
      end

      # Handle olist without Procedure title (direct procedure steps)
      if block.node_name == 'olist' && !block.title
        steps_content = generate_steps_from_block(block)
        track(block)
        next
      end

      # Skip additional resources content
      next if current_section == :additional_resources

      # Route content to appropriate section based on current state
      if current_section == :verification
        add_block_to_postreq(block, postreq_content)
        next
      end

      # Context elements (no title, before procedure content)
      case block.node_name
      when 'paragraph'
        next if block.title # Skip titled paragraphs (handled above)
        context_content << "      <p>#{DITAGenerator.convert_inline(block.lines.join(' '))}</p>"
        track(block)
      when 'listing', 'literal'
        lang = block.attributes['language'] || 'text'
        code = DITAGenerator.escape_xml(block.lines.join("\n"))
        context_content << "      <codeblock outputclass=\"language-#{lang}\">"
        context_content << code
        context_content << "      </codeblock>"
        track(block)
      when 'admonition'
        admon_type = block.attributes['name'] || 'note'
        context_content << "      <note type=\"#{admon_type}\">"
        if block.respond_to?(:blocks) && !block.blocks.empty?
          block.blocks.each do |child|
            if child.node_name == 'paragraph'
              context_content << "        <p>#{DITAGenerator.convert_inline(child.lines.join(' '))}</p>"
              track(child)
            end
          end
        elsif block.lines && !block.lines.empty?
          context_content << "        <p>#{DITAGenerator.convert_inline(block.lines.join(' '))}</p>"
        end
        context_content << "      </note>"
        track(block)
      when 'colist'
        context_content << "      <ol>"
        if block.respond_to?(:blocks) && !block.blocks.empty?
          block.blocks.each do |coitem|
            context_content << "        <li>#{DITAGenerator.convert_inline(coitem.text || '')}</li>"
            track(coitem)
          end
        end
        context_content << "      </ol>"
        track(block)
      when 'open'
        # Open block - process children inline
        if block.respond_to?(:blocks) && !block.blocks.empty?
          block.blocks.each do |child|
            case child.node_name
            when 'paragraph'
              context_content << "      <p>#{DITAGenerator.convert_inline(child.lines.join(' '))}</p>"
              track(child)
            when 'listing', 'literal'
              lang = child.attributes['language'] || 'text'
              code = DITAGenerator.escape_xml(child.lines.join("\n"))
              context_content << "      <codeblock outputclass=\"language-#{lang}\">"
              context_content << code
              context_content << "      </codeblock>"
              track(child)
            end
          end
        end
        track(block)
      end
    end

    # Build output in correct DITA order
    output = []

    # prereq first
    output << prereq_content if prereq_content

    # context second
    unless context_content.empty?
      output << "    <context>"
      output << context_content.join("\n")
      output << "    </context>"
    end

    # steps third
    output << steps_content if steps_content

    # postreq (verification steps) - comes after result in DITA
    unless postreq_content.empty?
      output << "    <postreq>"
      output << postreq_content.join("\n")
      output << "    </postreq>"
    end

    output.compact.join("\n")
  end

  def generate_prereq_from_block(block)
    prereq = []
    prereq << "    <prereq>"

    # Handle ulist with Prerequisites title
    if block.node_name == 'ulist'
      prereq << generate_prereq_list(block, 6)
    elsif block.respond_to?(:blocks) && !block.blocks.empty?
      # Handle section containing prerequisites
      block.blocks.each do |child|
        if child.node_name == 'ulist'
          prereq << generate_prereq_list(child, 6)
          track(child)
        end
      end
    end

    prereq << "    </prereq>"
    prereq.join("\n")
  end

  # Generate prerequisite list with support for nested lists
  def generate_prereq_list(ulist, indent)
    spaces = ' ' * indent
    list_content = []
    list_content << "#{spaces}<ul>"

    ulist.blocks.each do |item|
      # Check for nested content
      if item.respond_to?(:blocks) && !item.blocks.empty?
        list_content << "#{spaces}  <li>"
        list_content << "#{spaces}    <p>#{DITAGenerator.convert_inline(item.text)}</p>" if item.text && !item.text.empty?
        item.blocks.each do |child|
          if child.node_name == 'ulist'
            list_content << generate_prereq_list(child, indent + 4)
            track(child)
          end
        end
        list_content << "#{spaces}  </li>"
      else
        list_content << "#{spaces}  <li>#{DITAGenerator.convert_inline(item.text)}</li>"
      end
      track(item)
    end

    list_content << "#{spaces}</ul>"
    list_content.join("\n")
  end

  def generate_steps_from_block(block)
    steps = []
    steps << "    <steps>"

    # Handle olist directly
    items = block.node_name == 'olist' ? block.blocks : []
    olist_block = block.node_name == 'olist' ? block : nil

    # If it's a section, look for olist inside
    if block.respond_to?(:blocks) && block.node_name != 'olist'
      block.blocks.each do |child|
        if child.node_name == 'olist'
          items = child.blocks
          olist_block = child
        end
      end
    end

    items.each do |item|
      steps << "      <step>"
      steps << "        <cmd>#{DITAGenerator.convert_inline(item.text)}</cmd>"

      # Check for substeps or additional content
      if item.respond_to?(:blocks) && !item.blocks.empty?
        item.blocks.each do |child|
          case child.node_name
          when 'listing', 'literal'
            lang = child.attributes['language'] || 'text'
            code = DITAGenerator.escape_xml(child.lines.join("\n"))
            steps << "        <stepxmp>"
            steps << "          <codeblock outputclass=\"language-#{lang}\">"
            steps << code
            steps << "          </codeblock>"
            steps << "        </stepxmp>"
            track(child)
          when 'paragraph'
            steps << "        <info>"
            steps << "          <p>#{DITAGenerator.convert_inline(child.lines.join(' '))}</p>"
            steps << "        </info>"
            track(child)
          when 'admonition'
            # Handle NOTE, WARNING, IMPORTANT, etc. inside steps
            admon_type = child.attributes['name'] || 'note'
            steps << "        <info>"
            steps << "          <note type=\"#{admon_type}\">"
            if child.respond_to?(:blocks) && !child.blocks.empty?
              child.blocks.each do |admon_child|
                if admon_child.node_name == 'paragraph'
                  steps << "            <p>#{DITAGenerator.convert_inline(admon_child.lines.join(' '))}</p>"
                  track(admon_child)
                end
              end
            elsif child.lines && !child.lines.empty?
              steps << "            <p>#{DITAGenerator.convert_inline(child.lines.join(' '))}</p>"
            end
            steps << "          </note>"
            steps << "        </info>"
            track(child)
          when 'olist'
            # Handle nested steps (DITA 2.0 uses <steps> instead of deprecated <substeps>)
            steps << "        <steps>"
            child.blocks.each do |substep|
              steps << "          <step>"
              steps << "            <cmd>#{DITAGenerator.convert_inline(substep.text)}</cmd>"
              # Handle nested content in substeps
              if substep.respond_to?(:blocks) && !substep.blocks.empty?
                substep.blocks.each do |subchild|
                  case subchild.node_name
                  when 'listing', 'literal'
                    lang = subchild.attributes['language'] || 'text'
                    code = DITAGenerator.escape_xml(subchild.lines.join("\n"))
                    steps << "            <stepxmp>"
                    steps << "              <codeblock outputclass=\"language-#{lang}\">"
                    steps << code
                    steps << "              </codeblock>"
                    steps << "            </stepxmp>"
                    track(subchild)
                  when 'paragraph'
                    steps << "            <info>"
                    steps << "              <p>#{DITAGenerator.convert_inline(subchild.lines.join(' '))}</p>"
                    steps << "            </info>"
                    track(subchild)
                  end
                end
              end
              steps << "          </step>"
              track(substep)
            end
            steps << "        </steps>"
            track(child)
          when 'colist'
            # Callout list - annotations for code blocks
            steps << "        <info>"
            steps << "          <ol>"
            if child.respond_to?(:blocks) && !child.blocks.empty?
              child.blocks.each do |coitem|
                # Check if colist item has children (like admonitions)
                if coitem.respond_to?(:blocks) && !coitem.blocks.empty?
                  steps << "            <li>"
                  steps << "              <p>#{DITAGenerator.convert_inline(coitem.text || '')}</p>" if coitem.text && !coitem.text.empty?
                  coitem.blocks.each do |coitem_child|
                    case coitem_child.node_name
                    when 'admonition'
                      admon_type = coitem_child.attributes['name'] || 'note'
                      steps << "              <note type=\"#{admon_type}\">"
                      if coitem_child.respond_to?(:blocks) && !coitem_child.blocks.empty?
                        coitem_child.blocks.each do |admon_para|
                          if admon_para.node_name == 'paragraph'
                            steps << "                <p>#{DITAGenerator.convert_inline(admon_para.lines.join(' '))}</p>"
                            track(admon_para)
                          end
                        end
                      end
                      steps << "              </note>"
                      track(coitem_child)
                    when 'paragraph'
                      steps << "              <p>#{DITAGenerator.convert_inline(coitem_child.lines.join(' '))}</p>"
                      track(coitem_child)
                    end
                  end
                  steps << "            </li>"
                else
                  steps << "            <li>#{DITAGenerator.convert_inline(coitem.text || '')}</li>"
                end
                track(coitem)
              end
            elsif child.respond_to?(:items) && child.items
              child.items.each do |coitem|
                item_text = coitem.respond_to?(:text) ? coitem.text : coitem.to_s
                steps << "            <li>#{DITAGenerator.convert_inline(item_text)}</li>"
              end
            end
            steps << "          </ol>"
            steps << "        </info>"
            track(child)
          when 'ulist'
            # Unordered list inside a step
            steps << "        <info>"
            steps << "          <ul>"
            child.blocks.each do |li|
              steps << "            <li>#{DITAGenerator.convert_inline(li.text || '')}</li>"
              track(li)
            end
            steps << "          </ul>"
            steps << "        </info>"
            track(child)
          when 'open'
            # Open block - process children
            if child.respond_to?(:blocks) && !child.blocks.empty?
              child.blocks.each do |open_child|
                case open_child.node_name
                when 'listing', 'literal'
                  lang = open_child.attributes['language'] || 'text'
                  code = DITAGenerator.escape_xml(open_child.lines.join("\n"))
                  steps << "        <stepxmp>"
                  steps << "          <codeblock outputclass=\"language-#{lang}\">"
                  steps << code
                  steps << "          </codeblock>"
                  steps << "        </stepxmp>"
                  track(open_child)
                when 'paragraph'
                  steps << "        <info>"
                  steps << "          <p>#{DITAGenerator.convert_inline(open_child.lines.join(' '))}</p>"
                  steps << "        </info>"
                  track(open_child)
                when 'colist'
                  steps << "        <info>"
                  steps << "          <ol>"
                  if open_child.respond_to?(:blocks) && !open_child.blocks.empty?
                    open_child.blocks.each do |coitem|
                      steps << "            <li>#{DITAGenerator.convert_inline(coitem.text || '')}</li>"
                      track(coitem)
                    end
                  end
                  steps << "          </ol>"
                  steps << "        </info>"
                  track(open_child)
                end
              end
            end
            track(child)
          end
        end
      end

      steps << "      </step>"
      track(item)
    end

    track(olist_block) if olist_block
    steps << "    </steps>"
    steps.join("\n")
  end

  # Add a block's content to the postreq array
  def add_block_to_postreq(block, postreq_content, parent_title: 'Verification', position: nil)
    case block.node_name
    when 'paragraph'
      postreq_content << "      <p>#{DITAGenerator.convert_inline(block.lines.join(' '))}</p>"
      track(block)
    when 'listing', 'literal'
      lang = block.attributes['language'] || 'text'
      code = DITAGenerator.escape_xml(block.lines.join("\n"))
      postreq_content << "      <codeblock outputclass=\"language-#{lang}\">"
      postreq_content << code
      postreq_content << "      </codeblock>"
      track(block)
    when 'list_item'
      # Handle list items with their text and nested content
      if block.text && !block.text.empty?
        postreq_content << "      <p>#{DITAGenerator.convert_inline(block.text)}</p>"
      end
      # Handle nested content (e.g., code blocks inside list items)
      if block.respond_to?(:blocks) && !block.blocks.empty?
        block.blocks.each_with_index do |child, idx|
          emit_postreq_child_or_unhandled(child, postreq_content,
            parent_type: 'list_item', parent_title: parent_title, position: idx)
        end
      end
      track(block)
    when 'ulist'
      postreq_content << "      <ul>"
      block.blocks.each_with_index do |item, idx|
        postreq_content << "        <li>#{DITAGenerator.convert_inline(item.text)}</li>"
        # Handle nested content in list items (e.g., code blocks)
        if item.respond_to?(:blocks) && !item.blocks.empty?
          item.blocks.each_with_index do |child, child_idx|
            emit_postreq_child_or_unhandled(child, postreq_content,
              parent_type: 'list_item', parent_title: parent_title, position: child_idx)
          end
        end
        track(item)
      end
      postreq_content << "      </ul>"
      track(block)
    when 'olist'
      postreq_content << "      <ol>"
      block.blocks.each_with_index do |item, idx|
        postreq_content << "        <li>#{DITAGenerator.convert_inline(item.text)}</li>"
        # Handle nested content in list items
        if item.respond_to?(:blocks) && !item.blocks.empty?
          item.blocks.each_with_index do |child, child_idx|
            emit_postreq_child_or_unhandled(child, postreq_content,
              parent_type: 'list_item', parent_title: parent_title, position: child_idx)
          end
        end
        track(item)
      end
      postreq_content << "      </ol>"
      track(block)
    when 'admonition'
      admon_type = block.attributes['name'] || 'note'
      postreq_content << "      <note type=\"#{admon_type}\">"
      if block.respond_to?(:blocks) && !block.blocks.empty?
        block.blocks.each do |child|
          if child.node_name == 'paragraph'
            postreq_content << "        <p>#{DITAGenerator.convert_inline(child.lines.join(' '))}</p>"
            track(child)
          end
        end
      elsif block.lines && !block.lines.empty?
        postreq_content << "        <p>#{DITAGenerator.convert_inline(block.lines.join(' '))}</p>"
      end
      postreq_content << "      </note>"
      track(block)
    else
      # Emit UNHANDLED comment for unknown block types
      comment = ContentTracker.generate_unhandled_comment(block,
        parent_type: 'postreq', parent_title: parent_title, position: position)
      postreq_content << comment if comment
      track(block)
    end
  end

  # Emit child content or UNHANDLED comment for nested items in postreq
  def emit_postreq_child_or_unhandled(child, postreq_content, parent_type:, parent_title:, position:)
    case child.node_name
    when 'listing', 'literal'
      lang = child.attributes['language'] || 'text'
      code = DITAGenerator.escape_xml(child.lines.join("\n"))
      postreq_content << "        <codeblock outputclass=\"language-#{lang}\">"
      postreq_content << code
      postreq_content << "        </codeblock>"
      track(child)
    when 'paragraph'
      postreq_content << "        <p>#{DITAGenerator.convert_inline(child.lines.join(' '))}</p>"
      track(child)
    else
      # Emit UNHANDLED comment for unknown child types
      comment = ContentTracker.generate_unhandled_comment(child,
        parent_type: parent_type, parent_title: parent_title, position: position)
      postreq_content << comment if comment
      track(child)
    end
  end

  # Process a block's children into postreq content
  def generate_postreq_content(block, postreq_content, parent_title: 'Verification')
    return unless block.respond_to?(:blocks) && !block.blocks.empty?

    block.blocks.each_with_index do |child, idx|
      add_block_to_postreq(child, postreq_content, parent_title: parent_title, position: idx)
    end
  end
end
