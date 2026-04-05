# frozen_string_literal: true

RSpec.shared_examples 'platforms_spec' do |plugin, plugin_name|
  let(:puppetdb_session) { double }
  let(:puppet_db) { double }
  let(:list) { [OpenStruct.new(name: 'production', modules: [Puppet::Module.new('modulea', '/foo/bar', 'production'), Puppet::Module.new('moduleb', '/foo/baz', 'production')])] }
  let(:puppet_lookup) { double }
  let(:classes) { double }
  let(:facts) { double }

  it 'has a valid schema' do
    schema = plugin.schema

    expect(schema).to be_a_valid_schema
  end

  it "#{plugin_name}.run without errors" do
    allow(Puppet).to receive(:lookup).with(:environments).and_return(puppet_lookup)
    allow(puppet_lookup).to receive(:list).and_return(list)
    list[0].modules.each do |elem|
      allow(elem).to receive(:forge_module?).and_return(true)
    end
    allow(puppetdb_session).to receive(:puppet_db).and_return(puppet_db)
    allow(puppet_db).to receive(:request).with('', 'resources[certname, title] { type = "Class" }').and_return(classes)
    allow(classes).to receive(:data).and_return(
      [
        {
          'title' => 'ModuleA::Foo',
          'certname' => 'aaa',
        },
        {
          'title' => 'ModuleB::Bar',
          'certname' => 'bbb',
        },
      ],
    )
    allow(puppet_db).to receive(:request).with('', 'inventory[certname, facts.os.family] {}').and_return(facts)
    allow(facts).to receive(:data).and_return(
      [
        {
          'facts.os.family' => 'linux',
          'certname' => 'aaa',
        },
        {
          'facts.os.family' => 'windows',
          'certname' => 'bbb',
        },
      ],
    )
    expect(plugin.run(puppetdb_session)).to eq([
                                                 class_platforms: [
                                                   {
                                                     count: 1,
                                                     name: 'ModuleA::Foo',
                                                     platform: 'linux',
                                                   },
                                                   {
                                                     count: 1,
                                                     name: 'ModuleB::Bar',
                                                     platform: 'windows',
                                                   },
                                                 ],
                                               ])
  end

  it 'generates an example' do
    expect { plugin.example }.not_to raise_error
  end
end
