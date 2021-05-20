# frozen_string_literal: true

RSpec.describe Dropsonde::Metrics do
  let(:metric) { described_class.new }

  context 'with default' do
    it 'loads list of plugins' do
      expect(described_class.plugins.size).to eq(Dir.glob('lib/dropsonde/metrics/*').size)
    end

    # validates each plugin's description
    it 'generates example description' do
      expect(metric.list).to be_a(String)
    end

    # validates each plugin's schema
    it 'generates a schema' do
      expect(metric.schema).to be_an(Array)
    end

    # validates each plugin's example
    it 'generates example data' do
      expect(metric.example).to be_a(Hash)
    end
  end

  context 'with disabled plugins' do
    Dropsonde.settings[:disable] = [:puppetfiles]

    it 'disables plugins' do
      expect(described_class.plugins.size).to eq(Dir.glob('lib/dropsonde/metrics/*').size - 1)
    end
  end
end
