RSpec.describe Dropsonde do
  before(:each) do
    Dropsonde.settings = {}
  end

  it "allows settings to be set" do
    expect(Dropsonde.settings = {}).to eq({})
    expect(Dropsonde.settings = {:a => :b}).to eq({:a => :b})
  end

  it "raise an error if settings aren't set properly" do
    expect { Dropsonde.settings = 'bananna' }.to raise_error(RuntimeError)
  end

end
