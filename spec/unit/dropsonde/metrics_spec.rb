# frozen_string_literal: true

RSpec.describe Dropsonde::Metrics do
  let(:metrics) { described_class.new }

  context 'with enable => true' do
    it 'initialize without errors' do
      allow(Dropsonde).to receive(:settings).and_return(enable: %w[puppetfiles dependencies platforms modules environments])
      expect { described_class.new }.not_to raise_error
    end
  end

  context 'with default' do
    it 'loads list of plugins' do
      expect(described_class.plugins.size).to eq(Dir.glob('lib/dropsonde/metrics/*').size)
    end

    # validates each plugin's description
    it 'generates example description' do
      expect(metrics.list).to be_a(String)
    end

    # validates each plugin's schema
    it 'generates a schema' do
      expect(metrics.schema).to be_an(Array)
    end

    # validates each plugin's example
    it 'generates example data' do
      expect(metrics.example).to be_a(Hash)
    end

    it 'has a site id' do
      expect(metrics.siteid).to be_a(String)
    end

    it 'generates a report' do
      expect(metrics.report).to be_a(Hash)
    end

    it 'generates a preview' do
      expect(metrics.preview).to be_a(String)
    end

    it 'raise error for wrong correlation between schema and data' do
      fake_plugin = OpenStruct.new(
        name: 'fake-plugin',
        schema: [
          {
            "description": 'a value',
            "mode": 'NULLABLE',
            "name": 'foo',
            "type": 'INTEGER',
          },
        ],
        run: [
          bar: 'Wrong data',
        ],
      )

      begin
        expect { metrics.sanity_check_data(fake_plugin, fake_plugin.run) }.not_to raise_error
      rescue RSpec::Expectations::ExpectationNotMetError => e
        expect(e.message).to include 'ERROR: The fake-plugin plugin exported the following keys not documented in the schema: ["bar"]'
      end
    end

    it 'validates the correlation between schema and data' do
      fake_plugin = OpenStruct.new(
        name: 'fake-plugin',
        schema: [
          {
            "description": 'a value',
            "mode": 'NULLABLE',
            "name": 'foo',
            "type": 'INTEGER',
          },
        ],
        run: [
          foo: 3,
        ],
      )

      expect(metrics.sanity_check_data(fake_plugin, fake_plugin.run)).to eq([foo: 3])
    end

    it 'checks for duplicates and not raise error for valid schema' do
      fake_valid_schema = [
        {
          "description": 'The class name',
          "mode": 'NULLABLE',
          "name": 'foo',
          "type": 'STRING',
        },
        {
          "description": 'The class name',
          "mode": 'NULLABLE',
          "name": 'bar',
          "type": 'STRING',
        },
      ]

      expect { metrics.check_for_duplicates(fake_valid_schema) }.not_to raise_error
    end

    it 'checks for duplicates and raise error for invalid schema' do
      fake_valid_schema = [
        {
          "description": 'The class name',
          "mode": 'NULLABLE',
          "name": 'foo',
          "type": 'STRING',
        },
        {
          "description": 'The class name',
          "mode": 'NULLABLE',
          "name": 'foo',
          "type": 'STRING',
        },
      ]

      begin
        expect { metrics.check_for_duplicates(fake_valid_schema) }.not_to raise_error
      rescue RSpec::Expectations::ExpectationNotMetError => e
        expect(e.message).to include 'The schema defines duplicate keys: ["foo"]'
      end
    end

    it 'checks sanity schema with fake invalid schema' do
      fake_plugin1 = OpenStruct.new(
        name: 'fake-plugin1',
        schema: [
          {
            "description": 'The class name',
            "mode": 'NULLABLE',
            "type": 'STRING',
          },
        ],
      )

      fake_plugin2 = OpenStruct.new(
        name: 'fake-plugin2',
        schema: {
          "description": 'The class name',
          "name": 'foo',
          "mode": 'NULLABLE',
          "type": 'STRING',
        },
      )

      begin
        expect { metrics.sanity_check_schema(fake_plugin1) }.not_to raise_error
      rescue RSpec::Expectations::ExpectationNotMetError => e
        expect(e.message).to include 'The fake-plugin1 plugin schema has 1 missing names'
      end

      begin
        expect { metrics.sanity_check_schema(fake_plugin2) }.not_to raise_error
      rescue RSpec::Expectations::ExpectationNotMetError => e
        expect(e.message).to include 'The fake-plugin2 plugin schema is not an array of hashes'
      end
    end
  end

  context 'with dependencies plugin loaded' do
    dependencies = described_class.plugins[:dependencies]
    include_examples 'dependencies_spec', dependencies, 'dependencies'
  end

  context 'with environments plugin loaded' do
    environments = described_class.plugins[:environments]
    include_examples 'environments_spec', environments, 'environments'
  end

  context 'with modules plugin loaded' do
    modules = described_class.plugins[:modules]
    include_examples 'modules_spec', modules, 'modules'
  end

  context 'with platforms plugin loaded' do
    platforms = described_class.plugins[:platforms]
    include_examples 'platforms_spec', platforms, 'platforms'
  end

  context 'with puppetfiles plugin loaded' do
    puppetfiles = described_class.plugins[:puppetfiles]
    include_examples 'puppetfiles_spec', puppetfiles, 'puppetfiles'
  end

  context 'with disabled plugins' do
    Dropsonde.settings[:disable] = [:puppetfiles]

    it 'disables plugins' do
      expect(described_class.plugins.size).to eq(Dir.glob('lib/dropsonde/metrics/*').size - 1)
    end
  end
end
