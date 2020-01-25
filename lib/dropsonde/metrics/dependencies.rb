class Dropsonde::Metrics::Dependencies
  def self.initialize_modules
    # require any libraries needed here -- no need to load puppet; it's already initialized
  end

  def self.description
    <<~EOF
      This group of metrics discovers dependencies between modules in all
      environments. It will omit dependencies on private modules.
    EOF
  end

  def self.schema
    # return an array of hashes of a partial schema to be merged into the complete schema
    # See https://cloud.google.com/bigquery/docs/schemas#specifying_a_json_schema_file
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
    # return an array of hashes representing the data to be merged into the combined checkin
    environments = Puppet.lookup(:environments).list.map{|e|e.name}
    modules = environments.map do |env|
      Puppet.lookup(:environments).get(env).modules
    end.flatten

    # we want only PUBLIC modules that PRIVATE modules depend on
    dependencies = modules.map do|mod|
      next unless mod.dependencies
      next if Dropsonde::Cache.forgeModule? mod  # skip unless this is a private module

      # and return a list of all public modules it depends on
      mod.dependencies.select {|mod| Dropsonde::Cache.forgeModule? mod }
    end.flatten.compact

    [
      { :dependencies => dependencies },
    ]

  end

  def self.cleanup
    # run just after generating this metric
  end
end
