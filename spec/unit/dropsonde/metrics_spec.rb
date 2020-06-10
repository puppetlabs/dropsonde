RSpec.describe Dropsonde::Metrics do

  it "loads list of plugins" do
    expect(Dropsonde::Metrics.plugins.size).to eq(Dir.glob('lib/dropsonde/metrics/*').size)
  end

#   it "disables plugins" do
#     Dropsonde.settings[:disable] = [:puppetfiles]
#     expect(Dropsonde::Metrics.plugins.size).to eq(Dir.glob('lib/dropsonde/metrics/*').size - 1)
#   end

  it "generates a schema" do
    expect(subject.schema).to be_an(Array)
  end

end
