require 'little-plugger'

class Dropsonde::Metrics
  extend LittlePlugger( :path => 'dropsonde/metrics', :module => Dropsonde::Metrics)

  def initialize
    Dropsonde::Metrics.disregard_plugins(*Dropsonde.settings[:blacklist])
    Dropsonde::Metrics.initialize_plugins
  end

  def siteid
    return @siteid if @siteid

    sha2 = Digest::SHA512.new
    sha2.update Puppet.settings[:certname]
    sha2.update Puppet.settings[:cacert]
    sha2.update Dropsonde.settings[:seed] if Dropsonde.settings[:seed]
    @siteid = sha2.hexdigest
    @siteid
  end

  def list
    str  = "                    Loaded telemetry plugins\n"
    str << "                 ===============================\n\n"
    Dropsonde::Metrics.plugins.each do |name, plugin|
      str << name.to_s
      str << "\n--------\n"
      str << plugin.description.strip
      str << "\n\n"
    end
    if Dropsonde.settings[:blacklist]
      str << "Disabled plugins:\n"
      str << "  #{Dropsonde.settings[:blacklist].join(', ')}"
    end
    str
  end

  def schema
    schema = skeleton_schema
    Dropsonde::Metrics.plugins.each do |name, plugin|
      schema.concat(sanity_check_schema(plugin))
    end
    check_for_duplicates(schema)
    schema
  end

  def preview
    str  = "                      Puppet Telemetry Report Preview\n"
    str << "                      ===============================\n\n"
    Dropsonde::Metrics.plugins.each do |name, plugin|
      schema = plugin.schema

      plugin.setup
      data = sanity_check_data(plugin)
      plugin.cleanup

      str << plugin.name+"\n"
      str << "-------------------------------\n"
      str << plugin.description
      data.each do |row|
        key    = row.keys.first
        values = row.values.first

        desc = schema.find {|item| item[:name].to_sym == key.to_sym}[:description]
        str << "- #{key}: #{desc}\n"
        values.each do |item|
          str << "    #{item}\n"
        end
      end
      str << "\n\n"
    end
    str << "Site ID:\n"
    str << siteid
    str
  end

  def report
    snapshots = {}
    Dropsonde::Metrics.plugins.each do |name, plugin|
      plugin.setup
      sanity_check_data(plugin, plugin.run).each do |row|
        snapshots[row.keys.first] = {
          'value'     => row.values.first,
          'timestamp' => Time.now.iso8601,
        }
      end
      plugin.cleanup
    end

    results = skeleton_report
    results[:'self-service-analytics'][:snapshots] = snapshots
    results
  end

  def example
    require 'ipaddr'
    results = skeleton_report
    results[:message_id] = generate_guid
    results[:timestamp]  = rand((Time.now - 60 * 60 * 24 * 365)..Time.now).utc
    results[:ip]         = IPAddr.new(rand(2**32), Socket::AF_INET)
    results.delete(:'self-service-analytics')

    Dropsonde::Metrics.plugins.each do |name, plugin|
      sanity_check_data(plugin, plugin.example).each do |row|
        results.merge!(row)
      end
    end

    results
  end

  # We accept both the plugin and data gathered from the plugin so that
  # we can sanitize both data and example data
  def sanity_check_data(plugin, data)
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

  def skeleton_schema
    [
      {
        "description": "An ID that's unique for each checkin to Dujour.",
        "mode": "NULLABLE",
        "name": "message_id",
        "type": "STRING"
      },
      {
        "description": "A unique identifier for a site, derived as a hash of the CA certificate and optional seed.",
        "mode": "NULLABLE",
        "name": "site_id",
        "type": "BYTES"
      },
      {
        "description": "The name of the product.",
        "mode": "NULLABLE",
        "name": "product",
        "type": "STRING"
      },
      {
        "description": "Version of the project.",
        "mode": "NULLABLE",
        "name": "version",
        "type": "STRING"
      },
      {
        "description": "Time the checkin to Dujour occurred.",
        "mode": "NULLABLE",
        "name": "timestamp",
        "type": "TIMESTAMP"
      },
      {
        "description": "IP Address of node checking in to Dujour.",
        "mode": "NULLABLE",
        "name": "ip",
        "type": "STRING"
      }
    ]
  end

  def skeleton_report
    {
      "product": "popularity-module",
      "version": "1.0.0",
      "site_id": siteid,
      "self-service-analytics": {
        "snapshots": { }
      }
    }
  end

  def generate_guid
    "%s-%s-%s-%s-%s" % [
      (0..8).to_a.map{|a| rand(16).to_s(16)}.join,
      (0..4).to_a.map{|a| rand(16).to_s(16)}.join,
      (0..4).to_a.map{|a| rand(16).to_s(16)}.join,
      (0..4).to_a.map{|a| rand(16).to_s(16)}.join,
      (0..12).to_a.map{|a| rand(16).to_s(16)}.join
    ]
  end
end
