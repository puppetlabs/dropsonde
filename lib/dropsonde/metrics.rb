require 'little-plugger'

class Dropsonde::Metrics
  extend LittlePlugger( :path => 'dropsonde/metrics', :module => Dropsonde::Metrics)

  def initialize
    Dropsonde::Metrics.initialize_plugins
  end

  def schema
    schema = []
    Dropsonde::Metrics.plugins.each do |name, plugin|
      schema.concat(sanity_check_schema(plugin))
    end
    check_for_duplicates(schema)
    schema
  end

  def preview
    str  = "Puppet Telemetry Report Preview\n"
    str << "===============================\n"
    Dropsonde::Metrics.plugins.each do |name, plugin|
      schema = plugin.schema

      plugin.setup
      data = sanity_check_data(plugin)
      plugin.cleanup

      str << plugin.name+"\n"
      str << plugin.description+"\n"
      data.each do |row|
        key    = row.keys.first
        values = row.values.first

        desc = schema.find {|item| item[:name].to_sym == key.to_sym}[:description]
        str << "- #{key}: #{desc}\n"
        str << "    #{values}\n"
      end
      str << "-------------------------------\n\n"
    end
    str
  end

  def report
    results = []
    Dropsonde::Metrics.plugins.each do |name, plugin|
      plugin.setup
      results.concat(sanity_check_data(plugin))
      plugin.cleanup
    end
    results
  end

  def sanity_check_data(plugin)
    data = plugin.run
    keys_data   = data.map {|item| item.keys }.flatten.map(&:to_s)
    keys_schema = plugin.schema.map {|item| item[:name] }

    disallowed = (keys_data - keys_schema)

    raise "ERROR: The #{plugin.name} plugin exported the following keys not documented in the schema: #{disallowed}" unless disallowed.empty?

    data
  end

  def sanity_check_schema(plugin)
    schema = plugin.schema

    if schema.class != Array or schema.find {|item| item.class != Hash}
      raise "The #{plugin.name} plugin schema is not an array of hashes"
    end

    error = ''
    [:name, :type, :description].each do |field|
      count = schema.reject {|item| item[field] }.count
      next if count == 0

      error << "The #{plugin.name} plugin schema has #{count} missing #{field}s\n"
    end
    raise error unless error.empty?

    schema
  end

  def check_for_duplicates(schema)
    keys  = schema.map {|col| col[:name] }
    dupes = keys.select{ |e| keys.count(e) > 1 }.uniq

    raise "The schema defines duplicate keys: #{dupes}" unless dupes.empty?
  end
end
