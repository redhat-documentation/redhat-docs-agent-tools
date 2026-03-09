# DITA XML Generator module
# Provides common utilities for generating DITA XML content

module DITAGenerator
  DITA_VERSION = "2.0"

  # XML declaration and DOCTYPE templates
  DOCTYPES = {
    concept: '<!DOCTYPE concept PUBLIC "-//OASIS//DTD DITA 2.0 Concept//EN" "concept.dtd">',
    task: '<!DOCTYPE task PUBLIC "-//OASIS//DTD DITA 2.0 Task//EN" "task.dtd">',
    reference: '<!DOCTYPE reference PUBLIC "-//OASIS//DTD DITA 2.0 Reference//EN" "reference.dtd">',
    map: '<!DOCTYPE map PUBLIC "-//OASIS//DTD DITA 2.0 Map//EN" "map.dtd">'
  }.freeze

  # Generate XML declaration
  def self.xml_declaration
    '<?xml version="1.0" encoding="UTF-8"?>'
  end

  # Escape XML special characters
  def self.escape_xml(text)
    return '' if text.nil?
    text.to_s
      .gsub('&', '&amp;')
      .gsub('<', '&lt;')
      .gsub('>', '&gt;')
      .gsub('"', '&quot;')
      .gsub("'", '&apos;')
  end

  # Convert AsciiDoc inline formatting to DITA
  def self.convert_inline(text)
    return '' if text.nil?
    result = text.to_s

    # Convert HTML entities to readable characters first
    result = result.gsub('&#8594;', '->')
    result = result.gsub('&#8592;', '<-')
    result = result.gsub('&rarr;', '->')
    result = result.gsub('&larr;', '<-')

    # First, fix any <em> tags that Asciidoctor incorrectly inserted into URLs
    # This happens when URLs contain underscores like red_hat_ai becoming red<em>hat</em>ai
    # We need to remove these before processing links
    # Handle multiple <em> tags in a single href by looping until no more matches
    while result =~ /<a href="[^"]*<em>[^<]*<\/em>[^"]*"/
      result = result.gsub(/<a href="([^"]*)<em>([^<]*)<\/em>([^"]*)"/) do
        prefix = $1
        em_content = $2
        suffix = $3
        "<a href=\"#{prefix}_#{em_content}_#{suffix}\""
      end
    end

    # Convert HTML anchor tags to DITA xref FIRST, before any other formatting
    # External links: <a href="https://...">text</a> -> <xref href="..." format="html" scope="external">text</xref>
    result = result.gsub(/<a href="(https?:\/\/[^"]+)">([^<]*)<\/a>/) do
      href = $1
      link_text = $2
      "<xref href=\"#{href}\" format=\"html\" scope=\"external\">#{link_text}</xref>"
    end

    # Internal links: <a href="#anchor">text</a> -> <xref href="#anchor">text</xref>
    result = result.gsub(/<a href="(#[^"]+)">([^<]*)<\/a>/) do
      href = $1
      link_text = $2
      "<xref href=\"#{href}\">#{link_text}</xref>"
    end

    # Now convert HTML-style formatting from Asciidoctor to DITA (outside of href attributes)
    result = result.gsub(/<strong>([^<]+)<\/strong>/, '<b>\1</b>')
    result = result.gsub(/<em>([^<]+)<\/em>/, '<i>\1</i>')
    result = result.gsub(/<code>([^<]+)<\/code>/, '<codeph>\1</codeph>')

    # Convert AsciiDoc inline formatting (for raw AsciiDoc text)
    # Match italics only when surrounded by whitespace or at start/end - avoid URLs
    result = result.gsub(/(?<![a-zA-Z0-9\/])_([^_\s][^_]*[^_\s]|[^_\s])_(?![a-zA-Z0-9\/])/, '<i>\1</i>')
    result = result.gsub(/\*([^*]+)\*/, '<b>\1</b>')
    result = result.gsub(/`([^`]+)`/, '<codeph>\1</codeph>')

    # Convert AsciiDoc link macros to DITA xref
    # link:https://example.com[Link text] -> <xref href="..." format="html" scope="external">text</xref>
    result = result.gsub(/link:(https?:\/\/[^\[]+)\[([^\]]*)\]/) do
      href = $1
      link_text = $2
      "<xref href=\"#{href}\" format=\"html\" scope=\"external\">#{link_text}</xref>"
    end

    # Escape remaining ampersands (but preserve our tags and valid entities)
    result = result.gsub(/&(?!(amp|lt|gt|quot|apos|#\d+);)/, '&amp;')
    result
  end

  # Generate a valid DITA ID from text
  def self.generate_id(text)
    return 'topic' if text.nil? || text.empty?
    text.downcase
      .gsub(/[^a-z0-9\s-]/, '')
      .gsub(/\s+/, '-')
      .gsub(/-+/, '-')
      .gsub(/^-|-$/, '')
      .slice(0, 50)
  end
end
