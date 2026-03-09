# AST Node to Hash converter
# Converts Asciidoctor document nodes to a hash structure for analysis

class ASTConverter
  # Convert a node to hash and build a mapping from object_id to AST hash node
  # Returns [ast_hash, node_map] where node_map is { object_id => ast_hash_node }
  def self.node_to_hash_with_map(node, node_map = {})
    # Handle arrays (like definition list items)
    if node.is_a?(Array)
      return [node.map { |n| node_to_hash_with_map(n, node_map).first }, node_map]
    end

    # Handle non-node objects
    unless node.respond_to?(:node_name)
      h = { type: 'text', content: node.to_s }
      return [h, node_map]
    end

    h = { type: node.node_name }

    # Store the object_id so we can find this node later
    h[:_object_id] = node.object_id

    # Register this node in the map
    node_map[node.object_id] = h

    h[:id] = node.id if node.respond_to?(:id) && node.id
    h[:title] = node.title if node.respond_to?(:title) && node.title
    h[:level] = node.level if node.respond_to?(:level)
    h[:text] = node.text if node.respond_to?(:text) && node.text

    if node.respond_to?(:attributes) && node.attributes && !node.attributes.empty?
      h[:attributes] = node.attributes.sort.to_h rescue node.attributes
    end

    # Handle definition lists specially
    if node.node_name == 'dlist' && node.respond_to?(:items)
      h[:items] = node.items.map do |item|
        terms, desc = item
        term_texts = terms.map { |t| (t.text rescue t.to_s) }
        desc_text = (desc&.text rescue desc.to_s)
        { terms: term_texts, description: desc_text }
      end
    elsif node.respond_to?(:blocks) && !node.blocks.empty?
      h[:children] = node.blocks.map { |b| node_to_hash_with_map(b, node_map).first }
    elsif node.respond_to?(:lines)
      h[:text] = node.lines
    end

    # Also traverse list items for ulists/olists
    if node.respond_to?(:items) && node.items && !%w[dlist].include?(node.node_name)
      # List items are in :blocks for ulists/olists already, but double-check items
      node.items.each do |item|
        if item.is_a?(Array)
          item.each { |i| node_to_hash_with_map(i, node_map) if i.respond_to?(:node_name) }
        elsif item.respond_to?(:node_name)
          node_to_hash_with_map(item, node_map)
        end
      end
    end

    [h, node_map]
  end

  # Backward-compatible method that just returns the hash
  def self.node_to_hash(node)
    node_to_hash_with_map(node).first
  end

  # Clean up internal _object_id keys before serialization
  def self.clean_ast(ast)
    return ast.map { |n| clean_ast(n) } if ast.is_a?(Array)
    return ast unless ast.is_a?(Hash)

    cleaned = ast.reject { |k, _| k == :_object_id }
    cleaned.transform_values { |v| clean_ast(v) }
  end
end
