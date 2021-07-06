# frozen_string_literal: true

require 'date'
require 'json'
require 'fileutils'
require 'puppet_forge'

# cache class
class Dropsonde::Cache
  @autoupdate = false

  def initialize(path, ttl, autoupdate)
    FileUtils.mkdir_p(path)
    @path = "#{File.expand_path(path)}/forge.json"
    @ttl  = ttl
    @autoupdate = autoupdate

    @@cache = if File.file? @path # rubocop:disable Style/ClassVars
                JSON.parse(File.read(@path))
              else
                {
                  'timestamp' => '2000-1-1', # long before any puppet modules were released!
                  'modules' => [],
                }
              end

    PuppetForge.user_agent = 'Dropsonde Telemetry Client/0.0.1'
  end

  def modules
    @@cache['modules']
  end

  def cache
    @@cache
  end

  def self.forge_module?(mod)
    case mod
    when Puppet::Module
      modname = mod.forge_slug
    when Hash
      modname = mod[:name] || mod['name']
    when String
      modname = mod
    end
    return unless modname

    @@cache['modules'].include? modname.tr('/', '-')
  end

  def update
    puts 'Updating module cache...'
    iter   = PuppetForge::Module.all(sort_by: 'latest_release')
    newest = DateTime.parse(@@cache['timestamp'])

    @@cache['timestamp'] = iter.first.updated_at

    until iter.next.nil?
      # stop once we reach modules we've already cached
      break if DateTime.parse(iter.first.updated_at) <= newest

      @@cache['modules'].concat(iter.map { |mod| mod.slug })

      iter = iter.next
      print '.'
    end
    puts
    @@cache['modules'].sort!
    @@cache['modules'].uniq!

    File.write(@path, JSON.pretty_generate(@@cache))
  end

  def autoupdate
    return unless @autoupdate

    unless File.file? @path
      puts 'Dropsonde caches a list of all Forge modules to ensure that it only reports'
      puts 'usage data on public modules. Generating this cache may take some time on'
      puts "the first run and you'll see your screen fill up with dots."
      update
    end

    return update if (Date.today - File.mtime(@path).to_date).to_i > @ttl
  end
end
