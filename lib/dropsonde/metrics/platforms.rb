# frozen_string_literal: true

# platforms plugin
class Dropsonde::Metrics::Platforms
  def self.initialize_platforms
    # require any libraries needed here -- no need to load puppet; it's already initialized
    # All plugins are initialized before any metrics are generated.
  end

  def self.description
    <<~DESCRIPTION
      This group of metrics generates usage patterns by platform.
      Currently implemented is a list of classes, the platforms
      they are declared on, and a count of each combination.
    DESCRIPTION
  end

  def self.schema
    # return an array of hashes of a partial schema to be merged into the complete schema
    # See https://cloud.google.com/bigquery/docs/schemas#specifying_a_json_schema_file
    [
      {
        "fields": [
          {
            "description": 'The class name name',
            "mode": 'NULLABLE',
            "name": 'name',
            "type": 'STRING',
          },
          {
            "description": 'The osfamily of the node the class is declared on',
            "mode": 'NULLABLE',
            "name": 'platform',
            "type": 'STRING',
          },
          {
            "description": 'The number of time this combination is declared',
            "mode": 'NULLABLE',
            "name": 'count',
            "type": 'INTEGER',
          },
        ],
        "description": "List of all classes in the infrastructure and platforms they're declared on.",
        "mode": 'REPEATED',
        "name": 'class_platforms',
        "type": 'RECORD',
      },
    ]
  end

  def self.setup
    # run just before generating this metric
  end

  def self.run(puppetdb_session = nil)
    # skip this metric if we don't have an active PuppetDB connection
    return unless puppetdb_session

    classes = puppetdb_session.puppet_db.request('', 'resources[certname, title] { type = "Class" }').data
    facts   = puppetdb_session.puppet_db.request('', 'facts[certname, value] { name = "osfamily" }').data

    # All public Forge modules that are installed.
    modules = Puppet.lookup(:environments).list.map { |env|
      env.modules.select { |mod| mod.forge_module? }.map do |fmod|
        fmod.name
      end
    }.flatten.uniq

    data = classes.map { |item|
      # filter out any that don't come from public Forge modules
      mod = item['title'].split('::').first.downcase
      next unless modules.include? mod

      item['platform'] = facts.find { |fact|
        fact['certname'] == item['certname']
      }['value']

      {
        name: item['title'],
        platform: item['platform'],
      }
    }.compact

    data.each do |item|
      item[:count] = data.select { |i|
        i[:name] == item[:name] and i[:platform] == item[:platform]
      }.count
    end

    [
      class_platforms: data,
    ]
  end

  def self.example
    # this method is used to generate a table filled with randomized data to
    # make it easier to write data aggregation queries without access to the
    # actual private data that users have submitted.

    platforms = %w[RedHat Debian Windows Suse FreeBSD Darwin Archlinux AIX]
    classes   = ['', '::Config', '::Service', '::Server', '::Client', '::Packages']

    dropsonde_cache = Dropsonde::Cache.new('foo', 7, true)
    data = dropsonde_cache.modules
                          .sample(rand(35))
                          .map { |item|
      name = item.split('-').last.capitalize + classes.sample

      rand(5).times.map do
        {
          name: name,
          platform: platforms.sample,
          count: rand(1000),
        }
      end
    }.flatten

    [
      class_platforms: data.uniq,
    ]
  end

  def self.cleanup
    # run just after generating this metric
  end
end
