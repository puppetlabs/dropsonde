# frozen_string_literal: true

# modules plugin
class Dropsonde::Metrics::Modules
  def self.initialize_modules
    # require any libraries needed here -- no need to load puppet; it's already initialized
    # All plugins are initialized before any metrics are generated.
    require 'puppet/info_service'
    require 'puppet/info_service/class_information_service'
  end

  def self.description
    <<~DESCRIPTION
      This group of metrics exports name & version information about the public
      modules installed in all environments, ignoring private modules.
    DESCRIPTION
  end

  def self.schema
    # return an array of hashes of a partial schema to be merged into the complete schema
    # See https://cloud.google.com/bigquery/docs/schemas#specifying_a_json_schema_file
    [
      {
        "fields": [
          {
            "description": 'The module name',
            "mode": 'NULLABLE',
            "name": 'name',
            "type": 'STRING',
          },
          {
            "description": 'The module slug (author-name)',
            "mode": 'NULLABLE',
            "name": 'slug',
            "type": 'STRING',
          },
          {
            "description": 'The module version',
            "mode": 'NULLABLE',
            "name": 'version',
            "type": 'STRING',
          },
        ],
        "description": 'List of modules in all environments.',
        "mode": 'REPEATED',
        "name": 'modules',
        "type": 'RECORD',
      },
      {
        "fields": [
          {
            "description": 'The class name',
            "mode": 'NULLABLE',
            "name": 'name',
            "type": 'STRING',
          },
          {
            "description": 'How many nodes it is declared on',
            "mode": 'NULLABLE',
            "name": 'count',
            "type": 'INTEGER',
          },
        ],
        "description": 'List of classes and counts in all environments.',
        "mode": 'REPEATED',
        "name": 'classes',
        "type": 'RECORD',
      },
      {
        "fields": [
          {
            "description": 'The module name',
            "mode": 'NULLABLE',
            "name": 'name',
            "type": 'STRING',
          },
          {
            "description": 'The module slug (author-name)',
            "mode": 'NULLABLE',
            "name": 'slug',
            "type": 'STRING',
          },
          {
            "description": 'The module version',
            "mode": 'NULLABLE',
            "name": 'version',
            "type": 'STRING',
          },
        ],
        "description": 'List of modules whose classes are not declared in any environments.',
        "mode": 'REPEATED',
        "name": 'unused_modules',
        "type": 'RECORD',
      },
      {
        "fields": [
          {
            "description": 'The class name',
            "mode": 'NULLABLE',
            "name": 'name',
            "type": 'STRING',
          },
        ],
        "description": 'List of unused classes in all environments.',
        "mode": 'REPEATED',
        "name": 'unused_classes',
        "type": 'RECORD',
      },
    ]
  end

  def self.setup
    # run just before generating this metric
  end

  def self.run(puppetdb_session = nil)
    # return an array of hashes representing the data to be merged into the combined checkin
    environments = Puppet.lookup(:environments).list.map { |e| e.name }
    modules = environments.map { |env|
      Puppet.lookup(:environments).get(env).modules.map do |mod|
        next unless mod.forge_module?

        {
          name: mod.name,
          slug: mod.forge_slug,
          version: mod.version,
        }
      end
    }.flatten.compact.uniq

    if puppetdb_session
      # classes and how many nodes they're enforced on
      results = puppetdb_session.puppet_db.request('', 'resources[type, title] { type = "Class" }').data

      # select only classes from public modules.
      # Use uniq to reduce the iteration over very large datasets
      classes = results.uniq.map { |klass|
        title   = klass['title']
        modname = title.split('::').first.downcase
        next unless modules.find { |mod| mod[:name] == modname }

        {
          name: title,
          count: results.count { |row| row['title'] == title },
        }
      }.compact

      # now lets get a list of all classes so we can identify which are unused
      infoservice = Puppet::InfoService::ClassInformationService.new
      env_hash = {}
      environments.each { |env|
        manifests = Puppet.lookup(:environments).get(env).modules.inject([]) {|acc, mod|
          next acc unless mod.forge_module?

          acc.concat mod.all_manifests
        }
        env_hash[env] = manifests
      }

      klasses_per_env = infoservice.classes_per_environment(env_hash)

      installed_classes = klasses_per_env.inject([]) {|acc, (key, env)|
        names = env.inject([]) {|acc, (file, contents)|
          acc.concat contents[:classes].map {|c| c[:name] }
        }

        acc.concat names
      }

      unused_modules = installed_classes.map {|c| c.split('::').first }.sort.uniq
      classes.each {|c| unused_modules.delete(c[:name].split('::').first.downcase) }

      unused_classes = installed_classes.dup
      classes.each {|c| unused_classes.delete(c[:name].downcase) }
    else
      classes = []
      unused_modules  = []
      unused_classes  = []
    end

    [
      { modules: modules },
      { classes: classes },
      { unused_modules: unused_modules },
      { unused_classes: unused_classes }
    ]
  end

  def self.example
    # this method is used to generate a table filled with randomized data to
    # make it easier to write data aggregation queries without access to the
    # actual private data that users have submitted.

    versions = ['1.3.2', '0.0.1', '0.1.2', '1.0.0', '3.0.2', '7.10', '6.1.0', '2.1.0', '1.4.0']
    classes = ['', '::Config', '::Service', '::Server', '::Client', '::Packages']
    dropsonde_cache = Dropsonde::Cache.new('foo', 7, true)
    [
      modules: dropsonde_cache.modules
                              .sample(rand(100))
                              .map do |item|
                 {
                   name: item.split('-').last,
                   slug: item,
                   version: versions.sample,
                 }
               end,
      classes: dropsonde_cache.modules
                              .sample(rand(500))
                              .map do |item|
                 {
                   name: item.split('-').last.capitalize + classes.sample,
                   count: rand(750),
                 }
               end,
      unused_modules: dropsonde_cache.modules
                             .sample(rand(500))
                             .map { |item| item.split('-').last },
      unused_classes: dropsonde_cache.modules
                            .sample(rand(500))
                            .map { |item| item.split('-').last.capitalize + classes.sample },
    ]
  end

  def self.cleanup
    # run just after generating this metric
  end
end
