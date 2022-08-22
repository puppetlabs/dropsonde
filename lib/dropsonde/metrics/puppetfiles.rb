# frozen_string_literal: true

# puppetfiles plugin
class Dropsonde::Metrics::Puppetfiles
  def self.initialize_puppetfiles
    # require any libraries needed here -- no need to load puppet; it's already initialized
    # All plugins are initialized before any metrics are generated.
    require 'ripper'
  end

  def self.description
    <<~DESCRIPTION
      This generates interesting stats about Puppetfiles used in your environments,
      including whether your Puppetfiles have Ruby code in them.
    DESCRIPTION
  end

  def self.schema
    # return an array of hashes of a partial schema to be merged into the complete schema
    # See https://cloud.google.com/bigquery/docs/schemas#specifying_a_json_schema_file
    [
      {
        "fields": [
          {
            "description": 'The method name',
            "mode": 'NULLABLE',
            "name": 'name',
            "type": 'STRING',
          },
          {
            "description": 'How many times is it used',
            "mode": 'NULLABLE',
            "name": 'count',
            "type": 'INTEGER',
          },
        ],
        "description": 'Ruby methods used in Puppetfiles.',
        "mode": 'REPEATED',
        "name": 'puppetfile_ruby_methods',
        "type": 'RECORD',
      },
    ]
  end

  def self.setup
    # run just before generating this metric
  end

  def self.run(_puppetdb_session = nil)
    methods = Dir.entries(Puppet.settings[:environmentpath]).map { |entry|
      puppetfile = File.join(Puppet.settings[:environmentpath], entry, 'Puppetfile')

      next if entry.start_with? '.'
      next unless File.file? puppetfile

      tokens  = Ripper.sexp(File.read(puppetfile)).flatten
      indices = tokens.map.with_index { |a, i| (a == :command) ? i : nil }.compact

      indices.map { |i| tokens[i + 2] }
    }.flatten.compact

    methods.reject! { |name| %w[mod forge moduledir].include? name }

    methods = methods.uniq.map do |name|
      {
        name: name,
        count: methods.count(name),
      }
    end

    [
      { puppetfile_ruby_methods: methods },
    ]
  end

  def self.example
    # this method is used to generate a table filled with randomized data to
    # make it easier to write data aggregation queries without access to the
    # actual private data that users have submitted.
    [
      puppetfile_ruby_methods: [
        { name: 'require', count: rand(200) },
        { name: 'each',    count: rand(200) },
        { name: 'puts',    count: rand(200) },
        { name: 'select',  count: rand(200) },
        { name: 'reject',  count: rand(200) },
        { name: 'read',    count: rand(200) },
      ].shuffle,
    ]
  end

  def self.cleanup
    # run just after generating this metric
  end
end
