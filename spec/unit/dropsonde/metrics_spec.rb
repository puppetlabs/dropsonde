RSpec.describe Dropsonde::Metrics do

  it "loads list of plugins" do
    expect(Dropsonde::Metrics.plugins.size).to eq(Dir.glob('lib/dropsonde/metrics/*').size)
  end

#   it "blacklists plugins" do
#     Dropsonde.settings[:blacklist] = [:puppetfiles]
#     expect(Dropsonde::Metrics.plugins.size).to eq(Dir.glob('lib/dropsonde/metrics/*').size - 1)
#   end

  it "generates a schema" do
    expect(subject.schema).to be_an(Array)
  end

end
