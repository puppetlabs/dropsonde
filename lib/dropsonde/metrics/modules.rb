class Dropsonde::Metrics::Modules
  def self.initialize_modules
    # require any libraries needed here -- puppet is already initialized
  end

  def self.description
    <<~EOF
      This group of metrics exports name & version information about the public
      modules installed in all environments, ignoring private modules.
    EOF
  end

  def self.schema
    # return an array of hashes of a partial schema to be merged into the complete schema
    [
      {
        "fields": [
          {
            "description": "The module name",
            "mode": "NULLABLE",
            "name": "name",
            "type": "STRING"
          },
          {
            "description": "The module version",
            "mode": "NULLABLE",
            "name": "version",
            "type": "STRING"
          }
        ],
        "description": "List of modules in all environments.",
        "mode": "REPEATED",
        "name": "modules",
        "type": "RECORD"
      }
    ]
  end

  def self.setup
    # run just before generating this metric
  end

  def self.run
    # return a hash of data to be merged into the combined checkin
    environments = Puppet.lookup(:environments).list.map{|e|e.name}
    modules = environments.map do |env|
      Puppet.lookup(:environments).get(env).modules.map do|mod|
        {
          :name    => mod.metadata['name'] || "#{mod.author}-#{mod.name}",
          :version => mod.metadata['version']
        }
      end
    end.flatten.uniq

    [
      {
        :modules => modules.select {|mod| Dropsonde::Cache.modules.include? mod[:name] },
      }
    ]

  end

  def self.cleanup
    # run just after generating this metric
  end
end
