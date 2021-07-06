# frozen_string_literal: true

RSpec.describe Dropsonde::Cache do
  let(:dropsonde_cache) { described_class.new('foo', 7, true) }

  it 'loads default empty cache' do
    default = {
      'timestamp' => '2000-1-1', # long before any puppet modules were released!
      'modules' => [],
    }

    expect(File).to receive(:file?).with(%r{foo/forge.json}).and_return(false)

    expect(dropsonde_cache.cache).to eq(default)
  end

  it 'loads cache from disk' do
    cache = {
      'timestamp' => '2000-1-1', # long before any puppet modules were released!
      'modules' => %w[a b c],
    }

    expect(File).to receive(:file?).with(%r{foo/forge.json}).and_return(true)
    expect(File).to receive(:read).with(%r{foo/forge.json}).and_return(cache.to_json)

    expect(dropsonde_cache.cache).to eq(cache)
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

    dropsonde_cache.autoupdate
  end

  it 'updates successfuly when all modules are already cached' do
    allow(PuppetForge::Module).to receive(:all).with(sort_by: 'latest_release').and_return(
      [
        OpenStruct.new(
          slug: 'puppet-module_a',
          updated_at: '2000-1-1',
        ),
        OpenStruct.new(
          slug: 'puppet-module_b',
          updated_at: '2000-1-1',
        ),
      ].each,
    )
    expect { dropsonde_cache.update }.not_to raise_error
  end

  it 'updates successfuly with newest modules releases' do
    allow(PuppetForge::Module).to receive(:all).with(sort_by: 'latest_release').and_return(
      [
        OpenStruct.new(
          slug: 'puppet-module_a',
          updated_at: '2000-2-1', # a date after latest cache
        ),
        OpenStruct.new(
          slug: 'puppet-module_b',
          updated_at: '2000-2-1', # a date after latest cache
        ),
      ].each,
    )
    expect { dropsonde_cache.update }.not_to raise_error
  end
end
