class Dropsonde::Metrics::Dependencies
  def self.initialize_modules
    # require any libraries needed here -- puppet is already initialized
  end

  def self.description
    <<~EOF
      This group of metrics discovered dependencies between modules in all
      environments. It will omit dependencies on private modules.
    EOF
  end

  def self.schema
    # return an array of hashes of a partial schema to be merged into the complete schema
    [
      {
        "fields": [
          {
            "description": "The depended on module name",
            "mode": "NULLABLE",
            "name": "name",
            "type": "STRING"
          },
          {
            "description": "The depended on module version requirement",
            "mode": "NULLABLE",
            "name": "version_requirement",
            "type": "STRING"
          }
        ],
        "description": "List of modules that private modules in all environments depend on.",
        "mode": "REPEATED",
        "name": "dependencies",
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
      Puppet.lookup(:environments).get(env).modules
    end.flatten

    # we want only PUBLIC modules that PRIVATE modules depend on
    dependencies = modules.map do|mod|
      next unless mod.dependencies
      next if Dropsonde::Cache.modules.include? mod.metadata['name']

      # canonicalize to the 'user-project' style of name
      deps = mod.dependencies.map{|mod| mod['name'].tr!('/','-'); mod}

      deps.select {|mod| Dropsonde::Cache.modules.include? mod['name']}
    end.flatten.compact

    [
      { :dependencies => dependencies },
    ]

  end

  def self.cleanup
    # run just after generating this metric
  end
end
