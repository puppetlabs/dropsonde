# frozen_string_literal: true

RSpec.shared_examples 'dependencies_spec' do |plugin, plugin_name|
  let(:puppet_db) { double }
  let(:puppet_lookup) { double }
  let(:puppet_lookup_get) { double }
  let(:modules) { [OpenStruct.new(name: 'module_a', dependencies: %w[foo bar])] }

  it 'has a valid schema' do
    schema = plugin.schema

    expect(schema).to be_a_valid_schema
  end

  it "#{plugin_name}.run without errors" do
    allow(Puppet).to receive(:lookup).with(:environments).and_return(puppet_lookup).twice
    allow(puppet_lookup).to receive(:list).and_return([OpenStruct.new(name: 'production')])
    allow(puppet_lookup).to receive(:get).with('production').and_return(puppet_lookup_get)
    allow(puppet_lookup_get).to receive(:modules).and_return(modules)
    allow(Dropsonde::Cache).to receive(:forge_module?).with(modules.first).and_return(false)
    modules.first.dependencies.each do |dep|
      allow(Dropsonde::Cache).to receive(:forge_module?).with(dep).and_return(true)
    end

    expect(plugin.run).to eq([{ dependencies: %w[foo bar] }])
  end

  it 'generates an example' do
    expect { plugin.example }.not_to raise_error
  end
end
