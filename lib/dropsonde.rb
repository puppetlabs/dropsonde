# frozen_string_literal: true

require 'json'
require 'httpclient'
require 'puppetdb'
require 'inifile'
require 'puppet'

# This class handles caching module process, generate reports,
# fetchs all plugins defined in lib/dropsonde/metrics and also
# handle connection and request to PuppetDB.
class Dropsonde
  require 'dropsonde/cache'
  require 'dropsonde/metrics'
  require 'dropsonde/monkeypatches'
  require 'dropsonde/version'

  def self.puppet_settings_overrides
    overrides = []
    if (confdir = ENV['PUPPET_CONFDIR'])
      overrides << '--confdir'
      overrides << confdir
    end

    if (codedir = ENV['PUPPET_CODEDIR'])
      overrides << '--codedir'
      overrides << codedir
    end

    if (vardir = ENV['PUPPET_VARDIR'])
      overrides << '--vardir'
      overrides << vardir
    end

    if (logdir = ENV['PUPPET_LOGDIR'])
      overrides << '--logdir'
      overrides << logdir
    end

    overrides
  end

  Puppet.initialize_settings(puppet_settings_overrides)

  @pdbclient = nil
  @settings  = {}
  def self.settings=(arg)
    raise "Requires a Hash to set all settings at once, not a #{arg.class}" unless arg.is_a? Hash

    @settings = arg
  end

  class << self
    attr_reader :settings
  end

  def self.generate_schema
    puts JSON.pretty_generate(Dropsonde::Metrics.new.schema)
  end

  def self.list_metrics
    puts
    puts Dropsonde::Metrics.new.list
  end

  def self.generate_report(format, puppetdb_session = nil)
    case format
    when 'json'
      puts JSON.pretty_generate(Dropsonde::Metrics.new.report(puppetdb_session))
    when 'human'
      puts
      puts Dropsonde::Metrics.new.preview(puppetdb_session)
    else
      raise 'unknown format'
    end
  end

  def self.submit_report(endpoint, port)
    client = HTTPClient.new

    # The httpclient gem ships with some expired CA certificates.
    # This causes us to load the certs shipped with whatever
    # Ruby is used to execute this gem's commands, which are generally
    # more up-to-date, especially if using puppet-agent's Ruby.
    #
    # Note that this is no-op with Windows system Ruby.
    client.ssl_config.set_default_paths

    result = client.post("#{endpoint}:#{port}",
                         header: { 'Content-Type' => 'application/json' },
                         body: Dropsonde::Metrics.new.report.to_json)

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
      (0...size).each do |_i|
        file.write(metrics.example.to_json)
        file.write("\n")
      end
    end
  end

  def puppet_db
    return @pdbclient if @pdbclient

    config = File.join(Puppet.settings[:confdir], 'puppetdb.conf')

    return unless File.file? config

    server = IniFile.load(config)['main']['server_urls'].split(',').first

    @pdbclient = PuppetDB::Client.new({
                                        server: server,
                                        pem: {
                                          'key' => Puppet.settings[:hostprivkey],
                                          'cert' => Puppet.settings[:hostcert],
                                          'ca_file' => Puppet.settings[:localcacert],
                                        },
                                      })
  end
end
