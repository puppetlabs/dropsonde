# frozen_string_literal: true

RSpec.describe Dropsonde::Cache do
  let(:dropsonde_cache) { described_class.new('foo', 7, true) }

  it 'loads default empty cache' do
    default = {
      'timestamp' => '2000-1-1', # long before any puppet modules were released!
      'modules' => [],
    }

    expect(File).to receive(:file?).with(%r{foo/forge.json}).and_return(false)

    # dropsonde_cache.init('foo', 7, true)
    expect(dropsonde_cache.instance_variable_get(:@cache)).to eq(default)
  end

  it 'loads cache from disk' do
    cache = {
      'timestamp' => '2000-1-1', # long before any puppet modules were released!
      'modules' => %w[a b c],
    }

    expect(File).to receive(:file?).with(%r{foo/forge.json}).and_return(true)
    expect(File).to receive(:read).with(%r{foo/forge.json}).and_return(cache.to_json)

    # dropsonde_cache.init('foo', 7, true)
    expect(dropsonde_cache.instance_variable_get(:@cache)).to eq(cache)
  end

  it 'does not attempt to autoupdate before ttl has expired' do
    cache = {
      'timestamp' => '2000-1-1', # long before any puppet modules were released!
      'modules' => %w[a b c],
    }

    expect(File).to receive(:file?).with(%r{foo/forge.json}).and_return(true)
    expect(File).to receive(:read).with(%r{foo/forge.json}).and_return(cache.to_json)
    expect(File).to receive(:mtime).with(%r{foo/forge.json}).and_return(Date.today)

    expect(File).to receive(:file?).with(%r{foo/forge.json}).and_return(true)
    expect(dropsonde_cache).not_to receive(:update)

    # dropsonde_cache.init('foo', 7, true)
    dropsonde_cache.autoupdate
  end

  it 'will autoupdate after ttl has expired' do
    cache = {
      'timestamp' => '2000-1-1', # long before any puppet modules were released!
      'modules' => %w[a b c],
    }

    expect(File).to receive(:file?).with(%r{foo/forge.json}).and_return(true)
    expect(File).to receive(:read).with(%r{foo/forge.json}).and_return(cache.to_json)
    expect(File).to receive(:mtime).with(%r{foo/forge.json}).and_return((Date.today - 8))

    expect(File).to receive(:file?).with(%r{foo/forge.json}).and_return(true)
    expect(dropsonde_cache).to receive(:update).and_return(true)

    # dropsonde_cache.init('foo', 7, true)
    dropsonde_cache.autoupdate
  end
end
