# frozen_string_literal: true

RSpec.shared_examples 'puppetfiles_spec' do |plugin, _plugin_name|
  let(:env_dirs) { %w[production] }

  it 'initialize_puppetfiles without errors' do
    expect { plugin.initialize_puppetfiles }.not_to raise_error
  end

  it 'has a valid schema' do
    schema = plugin.schema

    expect(schema).to be_a_valid_schema
  end

  it '#run' do
    allow(Puppet).to receive(:settings).and_return(environmentpath: File.join(__dir__, '/../../', 'fixtures'))
    expect(plugin.run).to eq([puppetfile_ruby_methods: [{ name: 'puts', count: 1 }, { name: 'test', count: 1 }]])
  end

  it 'generates an example' do
    expect(plugin.example).to be_an(Array)
  end

  it 'has a description' do
    expect(plugin.description).to be_a(String)
  end
end
