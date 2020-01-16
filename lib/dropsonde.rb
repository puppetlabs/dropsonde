require 'json'
require 'httpclient'

class Dropsonde
  require 'dropsonde/cache'
  require 'dropsonde/metrics'

  def self.generate_schema
    puts JSON.pretty_generate(Dropsonde::Metrics.new.schema)
  end

  def self.generate_report
    puts Dropsonde::Metrics.new.preview
  end

  def self.submit_report(endpoint, port)
    report = {
      # I don't understand how this data structure relates to the published schemas
      "product": "popularity-module",
      "version": "1.0.0",
      "self-service-analytics": {
        "puppetserver.module-classes":{
          "value":[],  # Dropsonde::Metrics.new.report ?
          "timestamp":"2020-01-09T21:54:16.856Z"
        }
      }
    }

    client = HTTPClient.new()
    result = client.post("#{endpoint}:#{port}",
                  :header => {'Content-Type' => 'application/json'},
                  :body   => report.to_json
                )

                require 'pry'
                binding.pry

  end

end
