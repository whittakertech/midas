# frozen_string_literal: true

require 'find'

root = ARGV[0] || 'docs/api'
unless Dir.exist?(root)
  warn "normalize_yard_markdown: directory not found: #{root}"
  exit 0
end

files = []
Find.find(root) do |path|
  files << path if File.file?(path) && File.extname(path) == '.md'
end

files.each do |file|
  lines = File.readlines(file, chomp: true)
  out = []
  in_fence = false

  lines.each do |line|
    stripped = line.strip

    if stripped.start_with?('```')
      in_fence = !in_fence
      out << line
      next
    end

    starts_list_item = line.match?(/^(\*\s{3}|-\s)/)

    if starts_list_item && !in_fence
      prev = out.last
      prev_is_nonblank = prev && !prev.strip.empty?
      prev_is_list = prev&.match?(/^(\*\s{3}|-\s)/)
      prev_is_code_indent = prev&.start_with?('    ')

      # Python-Markdown requires a blank line before many list starts.
      out << '' if prev_is_nonblank && !prev_is_list && !prev_is_code_indent
    end

    out << line
  end

  normalized = out.join("\n")
  normalized << "\n" unless normalized.end_with?("\n")
  File.write(file, normalized)
end

puts "normalize_yard_markdown: processed #{files.length} files under #{root}"
