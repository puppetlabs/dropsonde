RSpec.describe Dropsonde::Cache do

  it "loads default empty cache" do
    default = {
                'timestamp' => '2000-1-1',  # long before any puppet modules were released!
                'modules'   => [],
              }

    expect(File).to receive(:file?).with(%r{foo/forge.json}).and_return(false)

    Dropsonde::Cache.init('foo', 7, true)
    expect(Dropsonde::Cache.class_variable_get(:@@cache)).to eq(default)
  end


  it "loads cache from disk" do
    cache = {
                'timestamp' => '2000-1-1',  # long before any puppet modules were released!
                'modules'   => ['a', 'b', 'c'],
              }

    expect(File).to receive(:file?).with(%r{foo/forge.json}).and_return(true)
    expect(File).to receive(:read).with(%r{foo/forge.json}).and_return(cache.to_json)

    Dropsonde::Cache.init('foo', 7, true)
    expect(Dropsonde::Cache.class_variable_get(:@@cache)).to eq(cache)
  end

  it "does not attempt to autoupdate before ttl has expired" do
    cache = {
                'timestamp' => '2000-1-1',  # long before any puppet modules were released!
                'modules'   => ['a', 'b', 'c'],
              }

    expect(File).to receive(:file?).with(%r{foo/forge.json}).and_return(true)
    expect(File).to receive(:read).with(%r{foo/forge.json}).and_return(cache.to_json)
    expect(File).to receive(:mtime).with(%r{foo/forge.json}).and_return(Date.today)

    expect(File).to receive(:file?).with(%r{foo/forge.json}).and_return(true)
    expect(Dropsonde::Cache).to_not receive(:update)

    Dropsonde::Cache.init('foo', 7, true)
    Dropsonde::Cache.autoupdate
  end

  it "will autoupdate after ttl has expired" do
    cache = {
                'timestamp' => '2000-1-1',  # long before any puppet modules were released!
                'modules'   => ['a', 'b', 'c'],
              }

    expect(File).to receive(:file?).with(%r{foo/forge.json}).and_return(true)
    expect(File).to receive(:read).with(%r{foo/forge.json}).and_return(cache.to_json)
    expect(File).to receive(:mtime).with(%r{foo/forge.json}).and_return((Date.today - 8))

    expect(File).to receive(:file?).with(%r{foo/forge.json}).and_return(true)
    expect(Dropsonde::Cache).to receive(:update).and_return(true)

    Dropsonde::Cache.init('foo', 7, true)
    Dropsonde::Cache.autoupdate
  end

end
