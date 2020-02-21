require 'date'
require 'json'
require 'fileutils'
require 'puppet_forge'

class Dropsonde::Cache
  @@autoupdate = false

  def self.init(path, ttl, autoupdate)
    FileUtils.mkdir_p(path)
    @@path = "#{File.expand_path(path)}/forge.json"
    @@ttl  = ttl
    @@autoupdate = autoupdate

    if File.file? @@path
      @@cache = JSON.parse(File.read(@@path))
    else
      @@cache = {
                'timestamp' => '2000-1-1',  # long before any puppet modules were released!
                'modules'   => [],
              }
    end

    PuppetForge.user_agent = "Dropsonde Telemetry Client/0.0.1"
  end

  def self.modules
    @@cache['modules']
  end

  def self.forgeModule?(mod)
    case mod
    when Puppet::Module
      modname = mod.forge_slug
    when Hash
      modname = mod[:name] || mod['name']
    when String
      modname = mod
    end
    return unless modname

    modules.include? modname.tr('/','-')
  end

  def self.update
    iter   = PuppetForge::Module.all(:sort_by => 'latest_release')
    newest = DateTime.parse(@@cache['timestamp'])

    @@cache['timestamp'] = iter.first.created_at

    until iter.next.nil?
      # stop once we reach modules we've already cached
      break if DateTime.parse(iter.first.created_at) <= newest

      @@cache['modules'].concat iter.map {|mod| mod.slug }

      iter = iter.next
      print '.'
    end
    @@cache['modules'].sort!
    @@cache['modules'].uniq!

    File.write(@@path, JSON.pretty_generate(@@cache))
  end

  def self.autoupdate
    return unless @@autoupdate

    update unless File.file? @@path

    if (Date.today - File.mtime(@@path).to_date).to_i > @@ttl
      update
    end
  end

end
