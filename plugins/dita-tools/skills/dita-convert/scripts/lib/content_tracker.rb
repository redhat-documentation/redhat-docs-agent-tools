# Content coverage tracker
# Tracks which AST nodes have been processed during conversion
# to ensure all content is accounted for in the output

require 'set'

class ContentTracker
  attr_reader :processed_nodes, :all_nodes, :warnings

  def initialize(ast_node_map = {})
    @processed_nodes = Set.new
    @all_nodes = []
    @warnings = []
    @ast_node_map = ast_node_map  # Maps object_id -> AST hash node
  end

  # Set the AST node map (for marking unhandled elements in-place)
  def set_ast_node_map(node_map)
    @ast_node_map = node_map
  end

  # Register all nodes from the document for tracking
  def register_document(doc)
    traverse_and_register(doc, [])
  end

  # Mark a node as processed
  def mark_processed(node, context = nil)
    node_id = node_identifier(node)
    @processed_nodes.add(node_id)
  end

  # Mark a block type as intentionally skipped (e.g., preamble wrapper)
  def mark_skipped(node, reason = nil)
    node_id = node_identifier(node)
    @processed_nodes.add(node_id)
  end

  # Check coverage and return report
  def coverage_report
    unprocessed = @all_nodes.reject { |n| @processed_nodes.include?(n[:id]) }

    # Filter out structural nodes that don't contain content
    content_nodes = unprocessed.reject { |n| structural_node?(n[:type]) }

    report = {
      total_nodes: @all_nodes.length,
      processed_nodes: @processed_nodes.length,
      unprocessed_count: content_nodes.length,
      unprocessed: content_nodes,
      coverage_percent: @all_nodes.empty? ? 100 : ((@processed_nodes.length.to_f / @all_nodes.length) * 100).round(1)
    }

    report
  end

  # Print warnings for unprocessed content
  def print_warnings
    report = coverage_report
    return if report[:unprocessed].empty?

    puts "\n=== Content Coverage Warnings ==="
    puts "Coverage: #{report[:coverage_percent]}% (#{report[:processed_nodes]}/#{report[:total_nodes]} nodes)"
    puts ""

    report[:unprocessed].each do |node|
      location = node[:path].join(' > ')
      text_preview = node[:text_preview] ? " - \"#{node[:text_preview]}\"" : ""
      puts "WARNING: Unhandled #{node[:type]}#{text_preview}"
      puts "         Location: #{location}"
    end

    puts "================================\n"
  end

  # Check if all content was processed
  def complete?
    coverage_report[:unprocessed].empty?
  end

  # Get unhandled elements in a format suitable for AST output
  def unhandled_elements
    report = coverage_report
    return [] if report[:unprocessed].empty?

    report[:unprocessed].map do |node|
      element = {
        type: node[:type],
        path: node[:path].join(' > ')
      }
      element[:title] = node[:node].title if node[:node].respond_to?(:title) && node[:node].title

      # Include source location if available
      if node[:node].respond_to?(:source_location) && node[:node].source_location
        element[:source_line] = node[:node].source_location
      end

      # Include the full content for listings/code blocks
      if %w[listing literal].include?(node[:type]) && node[:node].respond_to?(:lines)
        element[:content] = node[:node].lines
        element[:language] = node[:node].attributes['language'] if node[:node].respond_to?(:attributes)
      end

      # Include list item text
      if node[:type] == 'list_item' && node[:node].respond_to?(:text)
        element[:text] = node[:node].text
      end

      element
    end
  end

  # Mark unhandled elements directly in the AST at their location
  # This modifies the AST hash nodes in-place to add :unhandled information
  def mark_unhandled_in_ast
    return if @ast_node_map.empty?

    report = coverage_report
    return if report[:unprocessed].empty?

    report[:unprocessed].each do |node_info|
      asciidoc_node = node_info[:node]
      object_id = asciidoc_node.object_id

      # Find the corresponding AST hash node
      ast_node = @ast_node_map[object_id]
      next unless ast_node

      # Mark it as unhandled with details
      ast_node[:unhandled] = true
      ast_node[:unhandled_reason] = "No converter for node type '#{node_info[:type]}'"

      # Include source location if available
      if asciidoc_node.respond_to?(:source_location) && asciidoc_node.source_location
        ast_node[:source_line] = asciidoc_node.source_location
      end
    end
  end

  # Generate an XML comment for an unhandled node
  # Format: <!-- UNHANDLED: type=X language=Y parent=Z parent_title=W position=N
  # content here
  # -->
  def self.generate_unhandled_comment(node, parent_type: nil, parent_title: nil, position: nil)
    return nil unless node.respond_to?(:node_name)

    node_type = node.node_name
    attrs = ["type=#{node_type}"]

    # Add language for listings
    if %w[listing literal].include?(node_type) && node.respond_to?(:attributes)
      lang = node.attributes['language']
      attrs << "language=#{lang}" if lang
    end

    # Add parent context
    attrs << "parent=#{parent_type}" if parent_type
    attrs << "parent_title=#{parent_title}" if parent_title
    attrs << "position=#{position}" if position

    # Get content - try multiple methods
    content = nil
    if node.respond_to?(:lines) && node.lines && !node.lines.empty?
      content = node.lines.join("\n")
    elsif node.respond_to?(:text) && node.text && !node.text.to_s.empty?
      content = node.text.to_s
    elsif node.respond_to?(:blocks) && node.blocks && !node.blocks.empty?
      # For container blocks (sidebar, open, etc.), extract text from child blocks
      child_texts = node.blocks.map do |child|
        if child.respond_to?(:lines) && child.lines && !child.lines.empty?
          child.lines.join("\n")
        elsif child.respond_to?(:text) && child.text
          child.text.to_s
        end
      end.compact
      content = child_texts.join("\n\n") unless child_texts.empty?
    end

    # Build comment - escape "--" which is not allowed in XML comments
    if content && !content.empty?
      # Replace "--" with "- -" to make it valid XML comment content
      content = content.gsub('--', '- -')
    end

    comment_parts = ["<!-- UNHANDLED: #{attrs.join(' ')}"]
    if content && !content.empty?
      comment_parts << content
    end
    comment_parts << "-->"

    comment_parts.join("\n")
  end

  private

  def traverse_and_register(node, path)
    return unless node.respond_to?(:node_name)

    current_path = path + [node.node_name]
    node_id = node_identifier(node)

    # Extract text preview for better error messages
    text_preview = nil
    if node.respond_to?(:text) && node.text && !node.text.empty?
      text_preview = node.text.to_s[0, 50]
      text_preview += "..." if node.text.to_s.length > 50
    elsif node.respond_to?(:title) && node.title
      text_preview = node.title.to_s[0, 50]
    end

    @all_nodes << {
      id: node_id,
      type: node.node_name,
      path: current_path,
      text_preview: text_preview,
      node: node
    }

    # Traverse children
    if node.respond_to?(:blocks) && node.blocks
      node.blocks.each { |child| traverse_and_register(child, current_path) }
    end

    # Traverse list items (for ulists, olists)
    # Note: dlists use items differently - they are [terms, desc] arrays
    # We skip dlist items here as they're handled specially and the dlist block itself is tracked
    if node.respond_to?(:items) && node.items && node.node_name != 'dlist'
      node.items.each do |item|
        if item.is_a?(Array)
          item.each { |i| traverse_and_register(i, current_path) if i.respond_to?(:node_name) }
        elsif item.respond_to?(:node_name)
          traverse_and_register(item, current_path)
        end
      end
    end
  end

  def node_identifier(node)
    # Create unique identifier based on object_id
    node.object_id.to_s
  end

  # Nodes that are structural wrappers and don't contain content themselves
  def structural_node?(type)
    %w[document preamble].include?(type)
  end
end
