# frozen_string_literal: true

require 'yaml'
require 'date'

RSpec.describe 'SECURITY.md' do # rubocop:disable RSpec/DescribeClass
  let(:path) { File.expand_path('../../SECURITY.md', __dir__) }
  let(:content) { File.read(path) }
  let(:frontmatter) do
    match = content.match(/\A---\n(.*?)\n---\n/m)
    raise 'SECURITY.md must begin with YAML frontmatter' unless match

    YAML.safe_load(match[1], permitted_classes: [Date])
  end
  let(:versions) { frontmatter['versions'] }

  it 'has a versions mapping' do
    expect(versions).to be_a(Hash)
  end

  it 'uses quoted string version keys' do
    expect(versions.keys).to all(be_a(String))
    expect(versions.keys).to all(match(/\A\d+(\.\d+)*\z/))
  end

  it 'uses only allowed support values and fields' do
    versions.each_value do |entry|
      expect(entry.keys - %w[support eol]).to be_empty
      expect(entry['support']).to(satisfy { |v| %w[full security none].include?(v) })
    end
  end

  it 'uses ISO 8601 dates for eol' do
    versions.each_value do |entry|
      next unless entry.key?('eol')

      expect(entry['eol']).to be_a(Date)
    end
  end

  it 'lists every frontmatter version line in the Supported Versions table' do
    table = content[/## Supported Versions\n(.*?)\n## /m, 1]
    versions.each do |line, entry|
      row = table.lines.find { |l| l.start_with?('|') && l.split('|')[1].to_s.strip.delete('`') == line }
      expect(row).not_to be_nil, "no table row for version line #{line}"
      cells = row.split('|').map(&:strip)
      expect(cells[2].delete('`')).to eq(entry['support'])
      expect(cells[3]).to eq(entry['eol'] ? entry['eol'].iso8601 : '')
    end
  end
end
