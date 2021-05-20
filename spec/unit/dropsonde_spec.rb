# frozen_string_literal: true

RSpec.describe Dropsonde do
  before(:each) do
    described_class.settings = {}
  end

  it 'allows settings to be set' do
    expect(described_class.settings = {}).to eq({})
    expect(described_class.settings = { a: :b }).to eq({ a: :b })
  end

  it "raise an error if settings aren't set properly" do
    expect { described_class.settings = 'bananna' }.to raise_error(RuntimeError)
  end
end
