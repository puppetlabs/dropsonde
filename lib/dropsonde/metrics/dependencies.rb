# frozen_string_literal: true

# dependencies plugin
class Dropsonde::Metrics::Dependencies
  def self.initialize_dependencies
    # require any libraries needed here -- no need to load puppet; it's already initialized
    # All plugins are initialized before any metrics are generated.
  end

  def self.description
    <<~DESCRIPTION
      This group of metrics discovers dependencies between modules in all
      environments. It will omit dependencies on private modules.
    DESCRIPTION
  end

  def self.schema
    # return an array of hashes of a partial schema to be merged into the complete schema
    # See https://cloud.google.com/bigquery/docs/schemas#specifying_a_json_schema_file
    [
      {
        "fields": [
          {
            "description": 'The depended on module name',
            "mode": 'NULLABLE',
            "name": 'name',
            "type": 'STRING',
          },
          {
            "description": 'The depended on module version requirement',
            "mode": 'NULLABLE',
            "name": 'version_requirement',
            "type": 'STRING',
          },
        ],
        "description": 'List of modules that private modules in all environments depend on.',
        "mode": 'REPEATED',
        "name": 'dependencies',
        "type": 'RECORD',
      },
    ]
  end

  def self.setup
    # run just before generating this metric
  end

  def self.run(_puppetdb_session = nil)
    # return an array of hashes representing the data to be merged into the combined checkin
    environments = Puppet.lookup(:environments).list.map { |e| e.name }
    modules = environments.map { |env|
      Puppet.lookup(:environments).get(env).modules
    }.flatten

    # we want only PUBLIC modules that PRIVATE modules depend on
    dependencies = modules.map { |mod|
      next unless mod.dependencies
      next if Dropsonde::Cache.forge_module? mod # skip unless this is a private module

      # and return a list of all public modules it depends on
      mod.dependencies.select { |dep| Dropsonde::Cache.forge_module? dep }
    }.flatten.compact

    [
      { dependencies: dependencies },
    ]
  end

  def self.example
    # this method is used to generate a table filled with randomized data to
    # make it easier to write data aggregation queries without access to the
    # actual private data that users have submitted.

    dropsonde_cache = Dropsonde::Cache.new()
    versions = ['>= 1.5.2', '>= 4.3.2', '>= 3.0.0 < 4.0.0', '>= 2.2.1 < 5.0.0', '>= 5.0.0 < 7.0.0', '>= 4.11.0']
    [
      dependencies: dropsonde_cache.modules
                                   .sample(rand(250))
                                   .map do |item|
                      {
                        name: item,
                        version_requirement: versions.sample,
                      }
                    end,
    ]
  end

  def self.cleanup
    # run just after generating this metric
  end
end
