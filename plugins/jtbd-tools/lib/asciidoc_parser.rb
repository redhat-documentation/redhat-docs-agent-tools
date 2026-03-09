#!/usr/bin/env ruby
# asciidoc_parser.rb
# Shared AsciiDoc parsing utilities for JTBD tools.
# Provides common extraction functions used by all 5 JTBD scripts.

module AsciidocParser
  # Parse an AsciiDoc file and return a hash of extracted metadata.
  #
  # Returns a hash with:
  #   :title           - document title (String or nil)
  #   :content_type    - value of :_mod-docs-content-type: attribute (String or nil)
  #   :abstract        - text of [role="_abstract"] paragraph (String or nil)
  #   :headings        - array of { level:, text:, line: } hashes
  #   :includes        - array of { path:, line: } hashes
  #   :tables          - array of { headers:, rows:, line_start:, line_end: } hashes
  #   :procedure_steps - array of { text:, line:, has_substeps:, has_code: } hashes
  #   :has_prerequisites - boolean
  #   :has_verification  - boolean
  #   :executor_hints  - array of strings (e.g., "As a cluster administrator")
  #   :raw_content     - full file content string
  #   :lines           - array of line strings
  def self.parse(file_path)
    unless File.exist?(file_path)
      raise "File not found: #{file_path}"
    end

    content = File.read(file_path)
    lines = content.lines.map(&:chomp)

    {
      title: extract_title(lines),
      content_type: extract_content_type(content),
      abstract: extract_abstract(lines),
      headings: extract_headings(lines),
      includes: extract_includes(lines),
      tables: extract_tables(lines),
      procedure_steps: extract_procedure_steps(lines),
      has_prerequisites: has_prerequisites?(content),
      has_verification: has_verification?(content),
      executor_hints: extract_executor_hints(content),
      raw_content: content,
      lines: lines
    }
  end

  # Extract the document title (= Title line)
  def self.extract_title(lines)
    lines.each do |line|
      next if line =~ %r{^//}
      next if line =~ /^\s*$/
      next if line =~ /^:!?\S[^:]*:/
      if line =~ /^=\s+(.+)$/
        return Regexp.last_match(1).strip
      end
    end
    nil
  end

  # Extract content type from :_mod-docs-content-type: attribute
  def self.extract_content_type(content)
    if content =~ /^:_mod-docs-content-type:\s*(\S+)/
      return Regexp.last_match(1).strip
    end
    nil
  end

  # Extract the abstract paragraph (text following [role="_abstract"])
  def self.extract_abstract(lines)
    found_abstract_marker = false
    abstract_lines = []

    lines.each do |line|
      if line =~ /\[role=["']?_abstract["']?\]/
        found_abstract_marker = true
        next
      end

      if found_abstract_marker
        if line =~ /^\s*$/
          break unless abstract_lines.empty?
          next
        end
        # Stop at structural elements
        break if line =~ /^[=\.\[\|]/
        break if line =~ /^(?:ifn?def|ifeval|endif)::/
        break if line =~ /^include::/
        abstract_lines << line
      end
    end

    abstract_lines.empty? ? nil : abstract_lines.join(' ').strip
  end

  # Extract all headings with their levels
  def self.extract_headings(lines)
    headings = []
    in_comment = false
    in_code = false

    lines.each_with_index do |line, idx|
      if line =~ %r{^/{4,}\s*$}
        in_comment = !in_comment
        next
      end
      next if in_comment

      if line =~ /^(-{4,}|\.{4,}|={4,}|\+{4,})\s*$/
        in_code = !in_code
        next
      end
      next if in_code

      if line =~ /^(=+)\s+(.+)$/
        level = Regexp.last_match(1).length - 1 # = is level 0, == is level 1, etc.
        text = Regexp.last_match(2).strip
        headings << { level: level, text: text, line: idx + 1 }
      end
    end

    headings
  end

  # Extract include directives
  def self.extract_includes(lines)
    includes = []
    lines.each_with_index do |line, idx|
      next if line =~ %r{^//}
      if line =~ /^include::([^\[]+)\[/
        path = Regexp.last_match(1).strip
        includes << { path: path, line: idx + 1 }
      end
    end
    includes
  end

  # Extract tables with headers and rows
  def self.extract_tables(lines)
    tables = []
    in_table = false
    current_table = nil
    header_separator_seen = false

    lines.each_with_index do |line, idx|
      if line =~ /^\|===\s*$/
        if in_table
          # End of table
          current_table[:line_end] = idx + 1
          tables << current_table
          in_table = false
          current_table = nil
          header_separator_seen = false
        else
          # Start of table
          in_table = true
          current_table = { headers: [], rows: [], line_start: idx + 1, line_end: nil }
          header_separator_seen = false
        end
        next
      end

      next unless in_table

      # Skip empty lines
      next if line =~ /^\s*$/

      # Detect header separator (blank line after first row indicates headers)
      if line =~ /^\s*$/ && !header_separator_seen
        header_separator_seen = true
        next
      end

      # Extract cell content from lines starting with |
      if line =~ /^\|(.+)$/
        cells = Regexp.last_match(1).split('|').map(&:strip).reject(&:empty?)
        if current_table[:headers].empty? && !header_separator_seen
          current_table[:headers] = cells
          header_separator_seen = true
        else
          current_table[:rows] << cells unless cells.empty?
        end
      end
    end

    tables
  end

  # Extract procedure steps (ordered list items under .Procedure)
  def self.extract_procedure_steps(lines)
    steps = []
    in_procedure = false
    current_step = nil

    lines.each_with_index do |line, idx|
      if line =~ /^\.Procedure\s*$/i
        in_procedure = true
        next
      end

      # Stop at next section or block title (except .Verification, .Prerequisites)
      if in_procedure && line =~ /^(={2,}\s+|\.(?!\.)[A-Z])/
        break if line !~ /^\.(Verification|Prerequisites)/i
      end

      next unless in_procedure

      # Ordered list item (numbered step)
      if line =~ /^(\.\s+|\d+\.\s+)(.+)$/
        if current_step
          steps << current_step
        end
        step_text = Regexp.last_match(2).strip
        current_step = {
          text: step_text,
          line: idx + 1,
          has_substeps: false,
          has_code: false
        }
        next
      end

      next unless current_step

      # Check for substeps
      if line =~ /^[a-z]\.\s+/ || line =~ /^\.\.\s+/
        current_step[:has_substeps] = true
      end

      # Check for code blocks
      if line =~ /^(-{4,}|\.{4,})\s*$/ || line =~ /^\[source/
        current_step[:has_code] = true
      end
    end

    steps << current_step if current_step
    steps
  end

  # Check if document has prerequisites section
  def self.has_prerequisites?(content)
    content =~ /^\.Prerequisites\s*$/i ? true : false
  end

  # Check if document has verification section
  def self.has_verification?(content)
    content =~ /^\.Verification\s*$/i ? true : false
  end

  # Extract executor hints (phrases indicating who performs the action)
  def self.extract_executor_hints(content)
    hints = []
    patterns = [
      /As (?:a|an|the) ([^,\.\n]+)/i,
      /(?:cluster |project |namespace )?(?:administrator|admin|developer|operator|user|engineer)/i,
      /with (?:cluster-admin|admin|edit|view) (?:role|permissions?|privileges?|access)/i
    ]

    patterns.each do |pattern|
      content.scan(pattern).each do |match|
        hint = match.is_a?(Array) ? match[0] : match
        hints << hint.strip unless hints.include?(hint.strip)
      end
    end

    hints.uniq
  end

  # Format parsed data as JSON string
  def self.to_json(parsed)
    require 'json'
    # Convert to serializable hash (remove raw_content and lines for brevity)
    output = parsed.dup
    output.delete(:raw_content)
    output.delete(:lines)
    JSON.pretty_generate(output)
  end

  # Format parsed data as human-readable text
  def self.to_text(parsed)
    output = []
    output << "Title: #{parsed[:title] || '(none)'}"
    output << "Content Type: #{parsed[:content_type] || '(not set)'}"
    output << "Abstract: #{parsed[:abstract] || '(none)'}"
    output << "Has Prerequisites: #{parsed[:has_prerequisites]}"
    output << "Has Verification: #{parsed[:has_verification]}"

    if parsed[:executor_hints].any?
      output << "Executor Hints: #{parsed[:executor_hints].join('; ')}"
    end

    if parsed[:headings].any?
      output << ""
      output << "Headings (#{parsed[:headings].length}):"
      parsed[:headings].each do |h|
        indent = '  ' * h[:level]
        output << "  #{indent}[L#{h[:level]}] #{h[:text]} (line #{h[:line]})"
      end
    end

    if parsed[:includes].any?
      output << ""
      output << "Includes (#{parsed[:includes].length}):"
      parsed[:includes].each do |inc|
        output << "  #{inc[:path]} (line #{inc[:line]})"
      end
    end

    if parsed[:tables].any?
      output << ""
      output << "Tables (#{parsed[:tables].length}):"
      parsed[:tables].each_with_index do |tbl, i|
        output << "  Table #{i + 1} (lines #{tbl[:line_start]}-#{tbl[:line_end]}):"
        output << "    Headers: #{tbl[:headers].join(' | ')}" if tbl[:headers].any?
        output << "    Rows: #{tbl[:rows].length}"
      end
    end

    if parsed[:procedure_steps].any?
      output << ""
      output << "Procedure Steps (#{parsed[:procedure_steps].length}):"
      parsed[:procedure_steps].each_with_index do |step, i|
        flags = []
        flags << "substeps" if step[:has_substeps]
        flags << "code" if step[:has_code]
        flag_str = flags.empty? ? '' : " [#{flags.join(', ')}]"
        output << "  #{i + 1}. #{step[:text]}#{flag_str} (line #{step[:line]})"
      end
    end

    output.join("\n")
  end
end
