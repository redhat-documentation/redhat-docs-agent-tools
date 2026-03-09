#!/usr/bin/env ruby
# callouts.rb - Transform AsciiDoc callouts following Red Hat documentation guidelines
#
# Usage: ruby callouts.rb <file.adoc> [OPTIONS]
#
# Options:
#   --auto                 Automatically choose the best format (default)
#   --simple-sentence      Convert to simple sentence explanation
#   --definition-list      Convert to definition list with "where:"
#   --bulleted-list        Convert to bulleted list for structures
#   --dry-run              Show what would be changed without modifying files
#   -o <file>              Write output to specified file instead of modifying in place
#
# Red Hat Documentation Guidelines:
# 1. Simple sentence - For single command or line explanations
# 2. Definition list - For multiple parameters, placeholders, or user-replaced values
# 3. Bulleted list - For YAML structure explanations or multiple related lines
#
# IMPORTANT: Inline comments within code blocks are NOT supported!

require 'asciidoctor'
require 'tempfile'
require 'fileutils'
require 'set'

# Supported source block languages for callout transformation
SUPPORTED_LANGUAGES = /^(yaml|yml|bash|sh|shell|console|terminal|cmd|json|xml)$/i
YAML_LANGUAGES = /^(yaml|yml)$/i

# Find all conditional attributes used in the file
def find_conditional_attributes(content)
  attrs = Set.new
  content.scan(/(?:ifdef|ifndef)::(\S+)\[/) { |match| attrs.add(match[0]) }
  attrs
end

# Find source blocks by parsing with Asciidoctor using given attributes
def find_source_blocks_with_conditionals(content, lines)
  blocks = []
  seen_ranges = Set.new

  attrs = find_conditional_attributes(content)

  # Generate attribute combinations to try
  combinations = [{}]
  attrs.each { |attr| combinations << { attr => '' } }

  combinations.each do |attr_hash|
    doc = Asciidoctor.load(content, sourcemap: true, attributes: attr_hash)

    doc.find_by(context: :listing) do |block|
      next unless block.style == 'source'
      next unless block.lines

      lang = block.attr('language')
      next unless lang =~ SUPPORTED_LANGUAGES
      next unless block.lines.any? { |l| l =~ /<\d+>/ }

      callout_line = block.lines.find { |l| l =~ /<\d+>/ }
      next unless callout_line

      code_start = nil
      code_end = nil
      lines.each_with_index do |line, idx|
        if line.strip == callout_line.strip
          opening = idx - 1
          opening -= 1 while opening >= 0 && lines[opening] !~ /^----\s*$/
          next if opening < 0

          closing = idx + 1
          closing += 1 while closing < lines.length && lines[closing] !~ /^----\s*$/
          next if closing >= lines.length

          candidate_start = opening + 1
          candidate_end = closing
          candidate_lines = lines[candidate_start...candidate_end].map(&:strip)
          block_content = block.lines.map(&:strip)

          if candidate_lines == block_content
            code_start = candidate_start
            code_end = candidate_end
            break
          end
        end
      end
      next unless code_start && code_end

      range_key = "#{code_start}-#{code_end}"
      next if seen_ranges.include?(range_key)
      seen_ranges.add(range_key)

      block_line = code_start - 2
      block_line -= 1 while block_line >= 0 && lines[block_line] !~ /^\[source,/i

      blocks << {
        code_start: code_start,
        code_end: code_end,
        block_line: block_line,
        language: lang
      }
    end
  end

  blocks.sort_by { |b| b[:code_start] }
end

# Extract callout definitions with their numbers and text
def extract_callouts(lines, callout_start, callout_end)
  callouts = []
  j = callout_start

  while j < callout_end
    line = lines[j]

    # Skip conditional directives
    if line =~ /^(ifdef|ifndef)::\S+\[\]/ || line =~ /^endif::\[\]/
      j += 1
      next
    end

    # Exit if we hit a blank line or non-callout line
    break unless line =~ /^<(\d+)>\s*(.*)$/

    num = $1.to_i
    text_lines = [$2.strip]
    j += 1

    # Capture continuation lines
    while j < callout_end &&
          lines[j] !~ /^<\d+>/ &&
          lines[j] !~ /^\s*$/ &&
          lines[j] !~ /^(ifdef|ifndef)::\S+\[\]/ &&
          lines[j] !~ /^endif::\[\]/
      text_lines << lines[j].strip
      j += 1
    end

    callouts << { num: num, text: text_lines.join(' ') }
  end

  callouts
end

# Extract code line content for each callout (for definition lists and bulleted lists)
def extract_code_lines(lines, code_start, code_end)
  code_line_map = {}

  (code_start...code_end).each do |line_idx|
    line = lines[line_idx]
    if line =~ /^(\s*)(.*?)\s*<(\d+)>\s*$/
      indent = $1
      code_content = $2.rstrip
      num = $3.to_i

      # Remove trailing # if callout was preceded by comment marker
      code_content = code_content.sub(/\s*#\s*$/, '').rstrip

      # For definition lists: extract parameter name if present
      # For bulleted lists: extract structure path
      code_line_map[num] = {
        full: code_content,
        indent: indent,
        param: extract_parameter(code_content),
        struct_path: extract_structure_path(lines, code_start, line_idx, indent)
      }
    end
  end

  code_line_map
end

# Extract parameter name from code line (e.g., "<my_value>" or "--option")
def extract_parameter(code_content)
  # Match <placeholder>
  if code_content =~ /<([^>]+)>/
    return $1
  end

  # Match --option or -o
  if code_content =~ /-+([a-zA-Z][-a-zA-Z0-9]*)/
    return $&
  end

  # Match key: value in YAML
  if code_content =~ /^([a-zA-Z_][-a-zA-Z0-9_]*)\s*:/
    return $1
  end

  # Return cleaned content
  code_content.sub(/\s*\\$/, '').strip
end

# Extract structure path for YAML (e.g., "spec.workspaces")
def extract_structure_path(lines, code_start, current_idx, current_indent)
  path_parts = []
  indent_level = current_indent.length

  # Work backwards to build the path
  (code_start...current_idx).reverse_each do |idx|
    line = lines[idx]
    next if line =~ /<\d+>/  # Skip lines with callouts

    # Match key: value or key:
    if line =~ /^(\s*)([a-zA-Z_][-a-zA-Z0-9_]*)\s*:/
      line_indent = $1.length
      key = $2

      # Only include if this is a parent level
      if line_indent < indent_level
        path_parts.unshift(key)
        indent_level = line_indent
      end
    end
  end

  # Add current line's key
  current_line = lines[current_idx]
  if current_line =~ /([a-zA-Z_][-a-zA-Z0-9_]*)\s*:/
    path_parts << $1
  end

  path_parts.join('.')
end

# Remove callouts from code lines
def clean_code_lines(lines, code_start, code_end)
  new_code = []

  (code_start...code_end).each do |line_idx|
    line = lines[line_idx]

    if line =~ /^(\s*)(.*?)\s*<(\d+)>\s*$/
      indent = $1
      code_content = $2.rstrip

      # Remove trailing # if callout was preceded by comment marker
      code_content = code_content.sub(/\s*#\s*$/, '').rstrip

      new_code << "#{indent}#{code_content}" unless code_content.empty?
    else
      new_code << line
    end
  end

  new_code
end

# Determine best format automatically
def determine_auto_mode(language, callouts_count, code_line_map)
  # Always use definition list with "where:" prefix.
  # This maintains the connection between code lines and explanations,
  # works consistently for single and multiple callouts, and is the
  # preferred format per reviewer feedback.
  :definition_list
end

# Generate simple sentence explanation
def generate_simple_sentence(callouts, code_line_map)
  return [] if callouts.empty?

  callout = callouts.first
  ["", callout[:text]]
end

# Generate definition list with "where:" format using AsciiDoc :: syntax
def generate_definition_list(callouts, code_line_map)
  return [] if callouts.empty?

  lines = ["", "where:", ""]

  callouts.each do |callout|
    num = callout[:num]
    text = callout[:text]
    code_info = code_line_map[num]

    # Use full code line content as the term to maintain connection to code.
    # Fall back to extracted parameter, then "Line N".
    term = if code_info && !code_info[:full].to_s.strip.empty?
             "`#{code_info[:full].strip}`"
           elsif code_info && code_info[:param]
             param = code_info[:param]
             if code_info[:full] =~ /<#{Regexp.escape(param)}>/
               "`<#{param}>`"
             else
               "`#{param}`"
             end
           else
             "Line #{num}"
           end

    # Use original callout text as description (capitalize first letter)
    description = text.strip
    description = description[0].upcase + description[1..-1] if description.length > 1
    description += '.' unless description.end_with?('.')

    lines << "#{term}:: #{description}"
    lines << ""
  end

  lines
end

# Normalize verb to third-person singular for parallel sentence structure.
# Converts imperative ("define") to declarative ("defines") so all bullets
# in a list use consistent grammar.
VERB_NORMALIZATIONS = {
  'define'    => 'defines',
  'specify'   => 'specifies',
  'configure' => 'configures',
  'set'       => 'sets',
  'enable'    => 'enables',
  'disable'   => 'disables',
  'create'    => 'creates',
  'list'      => 'lists',
  'contain'   => 'contains',
  'include'   => 'includes',
  'reference' => 'references',
  'store'     => 'stores',
  'indicate'  => 'indicates',
  'determine' => 'determines',
  'control'   => 'controls',
  'provide'   => 'provides',
  'allow'     => 'allows',
  'restrict'  => 'restricts',
  'limit'     => 'limits',
  'map'       => 'maps',
  'assign'    => 'assigns',
  'declare'   => 'declares',
  'override'  => 'overrides',
  'trigger'   => 'triggers',
  'mount'     => 'mounts',
  'expose'    => 'exposes',
  'bind'      => 'binds',
  'run'       => 'runs',
  'use'       => 'uses',
  'add'       => 'adds',
  'remove'    => 'removes',
  'select'    => 'selects',
  'apply'     => 'applies',
  'deploy'    => 'deploys',
  'install'   => 'installs',
  'manage'    => 'manages',
  'connect'   => 'connects',
  'identify'  => 'identifies',
  'name'      => 'names',
  'hold'      => 'holds',
  'point'     => 'points',
  'represent' => 'represents',
  'describe'  => 'describes',
  'require'   => 'requires',
  'ensure'    => 'ensures',
  'prevent'   => 'prevents',
  'grant'     => 'grants',
  'deny'      => 'denies',
  'accept'    => 'accepts',
  'reject'    => 'rejects',
  'start'     => 'starts',
  'stop'      => 'stops',
  'pass'      => 'passes',
  'persist'   => 'persists',
  'handle'    => 'handles',
  'forward'   => 'forwards',
  'return'    => 'returns',
  'inject'    => 'injects',
  'attach'    => 'attaches',
  'detach'    => 'detaches',
  'link'      => 'links',
  'match'     => 'matches',
  'filter'    => 'filters',
  'route'     => 'routes',
  'label'     => 'labels',
  'annotate'  => 'annotates',
  'encrypt'   => 'encrypts',
  'authenticate' => 'authenticates',
  'authorize' => 'authorizes',
  'inherit'   => 'inherits',
  'extend'    => 'extends',
  'invoke'    => 'invokes',
  'execute'   => 'executes',
  'emit'      => 'emits',
  'publish'   => 'publishes',
  'subscribe' => 'subscribes',
  'watch'     => 'watches',
  'monitor'   => 'monitors',
  'track'     => 'tracks',
  'log'       => 'logs',
  'record'    => 'records',
  'fetch'     => 'fetches',
  'pull'      => 'pulls',
  'push'      => 'pushes',
  'sync'      => 'syncs',
  'update'    => 'updates',
  'delete'    => 'deletes',
  'patch'     => 'patches',
  'replace'   => 'replaces',
  'merge'     => 'merges',
  'split'     => 'splits',
  'migrate'   => 'migrates',
  'scale'     => 'scales',
  'replicate' => 'replicates',
  'schedule'  => 'schedules',
  'allocate'  => 'allocates',
  'reserve'   => 'reserves',
  'cache'     => 'caches',
  'buffer'    => 'buffers',
  'queue'     => 'queues',
  'load'      => 'loads',
  'initialize' => 'initializes',
  'terminate' => 'terminates',
  'check'     => 'checks',
  'validate'  => 'validates',
  'verify'    => 'verifies',
  'test'      => 'tests',
  'probe'     => 'probes',
  'scan'      => 'scans',
  'resolve'   => 'resolves',
  'notify'    => 'notifies',
  'report'    => 'reports',
  'retry'     => 'retries',
  'restart'   => 'restarts',
  'recover'   => 'recovers',
  'restore'   => 'restores',
  'revert'    => 'reverts',
  'rollback'  => 'rolls back',
  'upgrade'   => 'upgrades',
  'downgrade' => 'downgrades',
  'skip'      => 'skips',
  'ignore'    => 'ignores',
  'suppress'  => 'suppresses',
  'override'  => 'overrides',
  'activate'  => 'activates',
  'deactivate' => 'deactivates',
  'toggle'    => 'toggles',
  'swap'      => 'swaps',
  'rotate'    => 'rotates',
  'encode'    => 'encodes',
  'decode'    => 'decodes',
  'compress'  => 'compresses',
  'decompress' => 'decompresses',
  'serialize' => 'serializes',
  'deserialize' => 'deserializes',
  'parse'     => 'parses',
  'render'    => 'renders',
  'request'   => 'requests',
  'display'   => 'displays',
  'show'      => 'shows',
  'hide'      => 'hides',
  'protect'   => 'protects',
  'secure'    => 'secures',
  'lock'      => 'locks',
  'unlock'    => 'unlocks',
  'pin'       => 'pins',
  'unpin'     => 'unpins',
  'register'  => 'registers',
  'deregister' => 'deregisters',
  'unregister' => 'unregisters',
  'embed'     => 'embeds',
  'wrap'      => 'wraps',
  'unwrap'    => 'unwraps',
  'aggregate' => 'aggregates',
  'group'     => 'groups',
  'sort'      => 'sorts',
  'order'     => 'orders',
  'count'     => 'counts',
  'measure'   => 'measures',
  'calculate' => 'calculates',
  'compute'   => 'computes',
  'transform' => 'transforms',
  'convert'   => 'converts',
  'format'    => 'formats',
  'normalize' => 'normalizes',
  'sanitize'  => 'sanitizes',
  'clean'     => 'cleans',
  'trim'      => 'trims',
  'truncate'  => 'truncates',
  'pad'       => 'pads',
  'fill'      => 'fills',
  'populate'  => 'populates',
  'seed'      => 'seeds',
  'clone'     => 'clones',
  'copy'      => 'copies',
  'duplicate' => 'duplicates',
  'mirror'    => 'mirrors',
  'backup'    => 'backs up',
  'drain'     => 'drains',
  'cordon'    => 'cordons',
  'uncordon'  => 'uncordons',
  'taint'     => 'taints',
  'tolerate'  => 'tolerates',
  'evict'     => 'evicts',
  'preempt'   => 'preempts',
  'throttle'  => 'throttles',
}

# Build reverse lookup: "defines" => "defines", "define" => "defines"
VERB_LOOKUP = {}
VERB_NORMALIZATIONS.each do |imperative, declarative|
  VERB_LOOKUP[imperative] = declarative
  VERB_LOOKUP[declarative] = declarative
end

# Normalize a description to use third-person singular verb form.
# "Define the tasks" => "defines the tasks"
# "Defines the tasks" => "defines the tasks"
# "The list of tasks" => "the list of tasks" (no verb match, lowercase only)
def normalize_to_declarative(text)
  return text if text.nil? || text.empty?

  # Match leading verb (case-insensitive)
  if text =~ /^(\S+)(\s+.*)$/
    first_word = $1
    rest = $2
    lookup_key = first_word.downcase

    if VERB_LOOKUP.key?(lookup_key)
      return VERB_LOOKUP[lookup_key] + rest
    end
  end

  # No verb match — just lowercase the first character
  text[0].downcase + text[1..-1]
end

# Generate bulleted list for YAML structures
def generate_bulleted_list(callouts, code_line_map)
  return [] if callouts.empty?

  lines = [""]

  callouts.each do |callout|
    num = callout[:num]
    text = callout[:text]
    code_info = code_line_map[num]

    # Use structure path if available
    term = if code_info && !code_info[:struct_path].empty?
             "`#{code_info[:struct_path]}`"
           else
             "Line #{num}"
           end

    # Normalize to parallel third-person declarative form and ensure period
    description = normalize_to_declarative(text.strip)
    description += '.' unless description.end_with?('.')

    lines << "- #{term} #{description}"
  end

  lines << ""
  lines
end

# Process file with specified mode
def process_file(path, mode)
  content = File.read(path)
  lines = content.lines.map(&:chomp)
  modifications = []

  source_blocks = find_source_blocks_with_conditionals(content, lines)

  source_blocks.each do |block_info|
    code_start = block_info[:code_start]
    code_end = block_info[:code_end]
    language = block_info[:language]

    # Find callout start (skip conditionals and continuation markers)
    callout_start = code_end + 1
    while callout_start < lines.length &&
          (lines[callout_start] =~ /^(ifdef|ifndef)::\S+\[\]/ ||
           lines[callout_start] =~ /^endif::\[\]/ ||
           lines[callout_start] =~ /^\+\s*$/)
      callout_start += 1
    end

    # Find callout end
    callout_end = callout_start
    while callout_end < lines.length
      line = lines[callout_end]
      break if line =~ /^\s*$/ && line !~ /^<\d+>/
      break unless line =~ /^<\d+>/ || line =~ /^(ifdef|ifndef|endif)::/
      callout_end += 1 unless line =~ /^(ifdef|ifndef|endif)::/
      callout_end += 1 if line =~ /^(ifdef|ifndef|endif)::/
    end

    # Extract callouts and code lines
    callouts = extract_callouts(lines, callout_start, callout_end)
    next if callouts.empty?

    code_line_map = extract_code_lines(lines, code_start, code_end)
    new_code = clean_code_lines(lines, code_start, code_end)

    # Determine mode if auto
    selected_mode = mode == :auto ? determine_auto_mode(language, callouts.length, code_line_map) : mode

    # Generate explanation
    explanation = case selected_mode
                  when :simple_sentence
                    generate_simple_sentence(callouts, code_line_map)
                  when :definition_list
                    generate_definition_list(callouts, code_line_map)
                  when :bulleted_list
                    generate_bulleted_list(callouts, code_line_map)
                  else
                    []
                  end

    modifications << {
      start: code_start,
      end: callout_end,
      replacement: new_code + [lines[code_end]] + explanation,
      mode: selected_mode
    }
  end

  # Apply modifications in reverse order
  modifications.reverse.each do |mod|
    lines[mod[:start]...mod[:end]] = mod[:replacement]
  end

  { lines: lines, modifications: modifications }
end

# Parse command line arguments
input_file = nil
output_file = nil
mode = :auto
dry_run = false

i = 0
while i < ARGV.length
  arg = ARGV[i]
  case arg
  when '-o'
    output_file = ARGV[i + 1] if i + 1 < ARGV.length
    i += 2
  when /^-o(.+)$/
    output_file = $1
    i += 1
  when '--auto'
    mode = :auto
    i += 1
  when '--simple-sentence'
    mode = :simple_sentence
    i += 1
  when '--definition-list'
    mode = :definition_list
    i += 1
  when '--bulleted-list'
    mode = :bulleted_list
    i += 1
  when '--dry-run'
    dry_run = true
    i += 1
  when '--rewrite-deflists'
    mode = :definition_list
    i += 1
  when '--add-inline-comments'
    STDERR.puts "ERROR: #{arg} is deprecated. Use --auto, --simple-sentence, --definition-list, or --bulleted-list instead."
    STDERR.puts "See: https://redhat-documentation.github.io/supplementary-style-guide/#explain-commands-variables-in-code-blocks"
    exit 1
  else
    input_file = arg
    i += 1
  end
end

if input_file.nil?
  puts "Usage: ruby callouts.rb <file.adoc> [OPTIONS]"
  puts ""
  puts "Options:"
  puts "  --auto                 Automatically choose the best format (default)"
  puts "  --simple-sentence      Convert to simple sentence explanation"
  puts "  --definition-list      Convert to definition list with 'where:'"
  puts "  --bulleted-list        Convert to bulleted list for structures"
  puts "  --dry-run              Show what would be changed without modifying files"
  puts "  -o <file>              Write output to specified file instead of modifying in place"
  exit 1
end

unless File.exist?(input_file)
  puts "Error: File not found: #{input_file}"
  exit 1
end

output_file ||= input_file

# Process file
result = process_file(input_file, mode)
lines = result[:lines]
modifications = result[:modifications]

if dry_run
  puts "=== DRY RUN: Would write to #{output_file} ==="
  puts "Modifications: #{modifications.length} code blocks"
  modifications.each do |mod|
    puts "  - Line #{mod[:start] + 1}: #{mod[:mode]}"
  end
  puts ""
  puts lines.join("\n")
else
  tmp = Tempfile.new(['adoc', '.adoc'], File.dirname(output_file))
  tmp.write(lines.join("\n") + "\n")
  tmp.close
  FileUtils.mv(tmp.path, output_file)
  puts "Transformed #{modifications.length} code block(s) in #{output_file}"
  modifications.each do |mod|
    puts "  #{output_file}:#{mod[:start] + 1}: Converted using #{mod[:mode]}"
  end
end
