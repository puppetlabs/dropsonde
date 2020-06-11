RSpec.describe Dropsonde::Metrics do

  context "default" do
    it "loads list of plugins" do
      expect(Dropsonde::Metrics.plugins.size).to eq(Dir.glob('lib/dropsonde/metrics/*').size)
    end

    # validates each plugin's description
    it "generates example data" do
      expect(subject.list).to be_a(String)
    end

    # validates each plugin's schema
    it "generates a schema" do
      expect(subject.schema).to be_an(Array)
    end

    # validates each plugin's example
    it "generates example data" do
      expect(subject.example).to be_a(Hash)
    end
  end

  context "disabled plugins" do
    Dropsonde.settings[:disable] = [:puppetfiles]

    it "disables plugins" do
      expect(Dropsonde::Metrics.plugins.size).to eq(Dir.glob('lib/dropsonde/metrics/*').size - 1)
    end
  end
end
