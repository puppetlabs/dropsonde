require 'json'
require 'httpclient'
require 'puppetdb'
require 'inifile'

class Dropsonde
  require 'dropsonde/cache'
  require 'dropsonde/metrics'
  require 'dropsonde/monkeypatches'

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

  def self.generate_report
    puts
    puts Dropsonde::Metrics.new.preview
  end

  def self.submit_report(endpoint, port)
    client = HTTPClient.new()
    result = client.post("#{endpoint}:#{port}",
                  :header => {'Content-Type' => 'application/json'},
                  :body   => Dropsonde::Metrics.new.report.to_json
                )
  end

  def self.puppetDB
    return @@pdbclient if @@pdbclient

    config = File.join(Puppet.settings[:confdir], 'puppetdb.conf')

    return unless File.file? config

    server = IniFile.load(config)['main']['server_urls'].split(',').first

    @@pdbclient = PuppetDB::Client.new({
    :server => server,
    :pem    => {
        'key'     => Puppet.settings[:hostprivkey],
        'cert'    => Puppet.settings[:hostcert],
        'ca_file' => Puppet.settings[:localcacert],
    }})
  end

end
