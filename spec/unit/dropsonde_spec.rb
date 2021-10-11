# frozen_string_literal: true

RSpec.describe Dropsonde do
  before(:each) do
    described_class.settings = {}
  end

  it 'allows settings to be set' do
    expect(described_class.settings = {}).to eq({})
    expect(described_class.settings = { a: :b }).to eq({ a: :b })
  end

  it "raise an error if settings aren't set properly" do
    expect { described_class.settings = 'bananna' }.to raise_error(RuntimeError)
  end

  it 'generate_schema without errors' do
    expect { described_class.generate_schema }.not_to raise_error
  end

  it 'list_metrics without errors' do
    expect { described_class.list_metrics }.not_to raise_error
  end

  it 'generate_example without errors' do
    expect { described_class.generate_example(100, 'example.jsonl') }.not_to raise_error
  end

  context 'when generate_report without errors' do
    let(:puppetdb_session) { double }

    it 'in json format' do
      expect { described_class.generate_report('json') }.not_to raise_error
    end

    it 'in unknown format' do
      expect { described_class.generate_report('unknown format') }.not_to raise_error
    rescue RSpec::Expectations::ExpectationNotMetError => e
      expect(e.message).to include 'unknown format'
    end
  end

  context 'with puppetDB session' do
    let(:dropsonde) { described_class.new }

    it 'connect to puppetDB without errors' do
      expect { dropsonde.puppet_db }.not_to raise_error
    end

    it 'connect to puppetDB through puppetdb.conf' do
      allow(Puppet).to receive(:settings).and_return(confdir: File.join(__dir__, '/../', 'fixtures/puppet'))

      expect { dropsonde.puppet_db }.not_to raise_error
    end
  end

  context 'when submit report' do
    let(:http_client) {
      double("client",
             ssl_config: double("ssl_config", set_default_paths: "foo"))
    }
    let(:report) { double }
    let(:report_tojson) { double }
    let(:telemetry_report) { JSON.parse('{ "foo": "bar" }') }
    let(:response1) do
      OpenStruct.new(
        status: 200,
        body: '{ "newer": true, "link": "telemetry.example.com/download_new_version" }',
      )
    end
    let(:response2) do
      OpenStruct.new(
        status: 200,
        body: '{ "message": "report sent successfuly!" }',
      )
    end
    let(:response3) do
      OpenStruct.new(
        status: 500,
        body: '{ "message": "internal server error!" }',
      )
    end

    it 'submit_report with request for update telemetry' do
      allow(HTTPClient).to receive(:new).and_return(http_client)
      allow(Dropsonde::Metrics).to receive(:new).and_return(report)
      allow(report).to receive(:report).and_return(report_tojson)
      allow(report_tojson).to receive(:to_json).and_return(telemetry_report)
      allow(HTTPClient.new).to receive(:post).with(
        'example.com:1234',
        header: { 'Content-Type' => 'application/json' },
        body: telemetry_report,
      ).and_return(response1)

      expect { described_class.submit_report('example.com', 1234) }.not_to raise_error
    end

    it 'submit_report without errors' do
      allow(HTTPClient).to receive(:new).and_return(http_client)
      allow(Dropsonde::Metrics).to receive(:new).and_return(report)
      allow(report).to receive(:report).and_return(report_tojson)
      allow(report_tojson).to receive(:to_json).and_return(telemetry_report)
      allow(HTTPClient.new).to receive(:post).with(
        'example.com:1234',
        header: { 'Content-Type' => 'application/json' },
        body: telemetry_report,
      ).and_return(response2)

      expect { described_class.submit_report('example.com', 1234) }.not_to raise_error
    end

    it 'submit_report and receive response 500 - internal server error' do
      allow(HTTPClient).to receive(:new).and_return(http_client)
      allow(Dropsonde::Metrics).to receive(:new).and_return(report)
      allow(report).to receive(:report).and_return(report_tojson)
      allow(report_tojson).to receive(:to_json).and_return(telemetry_report)
      allow(HTTPClient.new).to receive(:post).with(
        'example.com:1234',
        header: { 'Content-Type' => 'application/json' },
        body: telemetry_report,
      ).and_return(response3)

      begin
        described_class.submit_report('example.com', 1234)
      rescue SystemExit => e
        expect(e.status).to eq(1)
      end
    end
  end
end
