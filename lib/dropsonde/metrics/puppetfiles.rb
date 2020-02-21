class Dropsonde::Metrics::Puppetfiles
  def self.initialize_puppetfiles
    # require any libraries needed here -- no need to load puppet; it's already initialized
    # All plugins are initialized before any metrics are generated.
    require 'ripper'
  end

  def self.description
    <<~EOF
      This generates interesting stats about Puppetfiles used in your environments,
      including whether your Puppetfiles have Ruby code in them.
    EOF
  end

  def self.schema
    # return an array of hashes of a partial schema to be merged into the complete schema
    # See https://cloud.google.com/bigquery/docs/schemas#specifying_a_json_schema_file
    [
      {
        "fields": [
          {
            "description": "The method name",
            "mode": "NULLABLE",
            "name": "name",
            "type": "STRING"
          },
          {
            "description": "How many times is it used",
            "mode": "NULLABLE",
            "name": "count",
            "type": "INTEGER"
          }
        ],
        "description": "Ruby methods used in Puppetfiles.",
        "mode": "REPEATED",
        "name": "puppetfile_ruby_methods",
        "type": "RECORD"
      }
    ]
  end

  def self.setup
    # run just before generating this metric
  end

  def self.run
    methods = Dir.entries(Puppet.settings[:environmentpath]).map do |entry|
      puppetfile = File.join(Puppet.settings[:environmentpath], entry, 'Puppetfile')

      next if entry.start_with? '.'
      next unless File.file? puppetfile

      tokens  = Ripper.sexp(File.read(puppetfile)).flatten
      indices = tokens.map.with_index {|a, i| a == :command ? i : nil}.compact

      indices.map {|i| tokens[i+2] }
    end.flatten.compact

    methods.reject! {|name| ['mod', 'forge', 'moduledir'].include? name }

    methods = methods.uniq.map do |name|
      {
        :name  => name,
        :count => methods.count(name),
      }
    end

    [
      { :puppetfile_ruby_methods => methods },
    ]
  end

  def self.cleanup
    # run just after generating this metric
  end
end
