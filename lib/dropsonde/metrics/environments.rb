class Dropsonde::Metrics::Environments
  def self.initialize_environments
    # Require any libraries needed here -- no need to load puppet or puppetdb;
    # they're already loaded. This hook is named after the class name.
    # All plugins are initialized at startup before any metrics are generated.
  end

  def self.description
    # This is a Ruby squiggle heredoc; just a multi-line string with indentation removed
    <<~EOF
      This group of metrics gathers information about environments.
    EOF
  end

  def self.schema
    # return an array of hashes of a partial schema to be merged into the complete schema
    [
      {
        "description": "The number of environments",
        "mode": "NULLABLE",
        "name": "environment_count",
        "type": "INTEGER"
      }
    ]
  end

  def self.setup
    # run just before generating this metric
  end

  def self.run
    # return an array of hashes representing the data to be merged into the combined checkin
    [
      :environment_count => Puppet.lookup(:environments).list.count,
    ]
  end

  def self.example
    # this method is used to generate a table filled with randomized data to
    # make it easier to write data aggregation queries without access to the
    # actual private data that users have submitted.
    [
      :environment_count => rand(1..100),
    ]
  end

  def self.cleanup
    # run just after generating this metric
  end
end
