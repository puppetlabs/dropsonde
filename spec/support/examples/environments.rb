# frozen_string_literal: true

RSpec.shared_examples 'environments_spec' do |plugin, plugin_name|
  let(:puppet_lookup) { double }

  it 'has a valid schema' do
    schema = plugin.schema

    expect(schema).to be_a_valid_schema
  end

  it "#{plugin_name}.run without errors" do
    allow(Puppet).to receive(:lookup).with(:environments).and_return(puppet_lookup)
    allow(puppet_lookup).to receive(:list).and_return(%w[production development])

    expect(plugin.run).to eq([environment_count: 2])
  end
end
