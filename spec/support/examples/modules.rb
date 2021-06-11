# frozen_string_literal: true

RSpec.shared_examples 'modules_spec' do |plugin, plugin_name|
  let(:puppetdb_session) { double }
  let(:puppet_db) { double }
  let(:modules) { [Puppet::Module.new('module_a', '/foo/bar', 'production'), Puppet::Module.new('module_b', '/foo/baz', 'production')] }
  let(:puppet_lookup) { double }
  let(:puppet_lookup_get) { double }
  let(:results) { double }

  it 'has a valid schema' do
    schema = plugin.schema

    expect(schema).to be_a_valid_schema
  end

  it "#{plugin_name}.run without errors" do
    allow(Puppet).to receive(:lookup).with(:environments).at_least(3).and_return(puppet_lookup)
    allow(puppet_lookup).to receive(:list).and_return([OpenStruct.new(name: 'production')])
    allow(puppet_lookup).to receive(:get).with('production').and_return(puppet_lookup_get)
    allow(puppet_lookup_get).to receive(:modules).and_return(modules)
    modules.each do |puppet_module|
      allow(puppet_module).to receive(:forge_module?).and_return(true)
    end
    allow(puppetdb_session).to receive(:puppet_db).and_return(puppet_db)
    allow(puppet_db).to receive(:request).with('', 'resources[type, title] { type = "Class" }').and_return(results)
    allow(results).to receive(:data).and_return(
      [
        {
          'title' => 'Module_A::Foo',
        },
        {
          'title' => 'Module_B::Bar',
        },
      ],
    )

    expect(plugin.run(puppetdb_session)[0][:modules].map { |mod| mod[:name] }).to eq(%w[module_a module_b])
    expect(plugin.run(puppetdb_session)[1][:classes]).to eq([{ name: 'Module_A::Foo', count: 1 }, { name: 'Module_B::Bar', count: 1 }])
    expect(plugin.run[1][:classes]).to eq([])
  end

  it 'generates an example' do
    expect { plugin.example }.not_to raise_error
  end
end
