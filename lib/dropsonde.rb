require 'json'
require 'httpclient'
require 'puppetdb'
require 'inifile'
require 'puppet'

class Dropsonde
  require 'dropsonde/cache'
  require 'dropsonde/metrics'
  require 'dropsonde/monkeypatches'
  require 'dropsonde/version'

  Puppet.initialize_settings

  @@pdbclient = nil
  @@settings  = {}
  def self.settings=(arg)
    raise "Requires a Hash to set all settings at once, not a #{arg.class}" unless arg.is_a? Hash
    @@settings = arg
  end

  def self.settings
    @@settings
  end

  def self.generate_schema
    puts JSON.pretty_generate(Dropsonde::Metrics.new.schema)
  end

  def self.list_metrics
    puts
    puts Dropsonde::Metrics.new.list
  end

  def self.generate_report(format)
    case format
    when 'json'
      puts JSON.pretty_generate(Dropsonde::Metrics.new.report)
    when 'human'
      puts
      puts Dropsonde::Metrics.new.preview
    else
      raise "unknown format"
    end
  end

  def self.submit_report(endpoint, port)
    client = HTTPClient.new()
    result = client.post("#{endpoint}:#{port}",
                  :header => {'Content-Type' => 'application/json'},
                  :body   => Dropsonde::Metrics.new.report.to_json
                )

    if result.status == 200
      data = JSON.parse(result.body)
      if data['newer']
        puts 'A newer version of the telemetry client is available:'
        puts "  -- #{data['link']}"
      else
        puts data['message']
      end
    else
      puts 'Failed to submit report'
      puts JSON.pretty_generate(result.body) if Dropsonde.settings[:verbose]
      exit 1
    end
  end

  def self.generate_example(size, filename)
    metrics = Dropsonde::Metrics.new
    File.open(filename, 'w') do |file|
      for i in 0...size
        file.write(metrics.example.to_json)
        file.write("\n")
      end
    end
  end

  def self.puppetDB
    @@client ||= ::PuppetDB::Client.new({
      :server => "#{ENV['PUPPETDB_URL'] || Puppet::Util::Puppetdb.config.server_urls[0]}",
      :pem    => {
        'key'     => ENV['PUPPETDB_KEY_FILE'] || Puppet[:hostprivkey],
        'cert'    => ENV['PUPPETDB_CERT_FILE'] || Puppet[:hostcert],
        'ca_file' => ENV['PUPPETDB_CACERT_FILE'] || Puppet[:localcacert],
      }
    }, 4)
  end
end
