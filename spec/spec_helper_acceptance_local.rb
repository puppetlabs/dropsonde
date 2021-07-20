# frozen_string_literal: true

require 'puppet_litmus'
require 'singleton'
require 'ostruct'

def run_local_command(command, opts = {})
  result = Open3.capture3(command)
  if opts[:expect_failures] || result[2] != 0
    if opts[:expect_failures]
      return OpenStruct.new(
        stdout: "ERROR: #{result[0]}",
        stderr: result[1],
        exit_code: result[2],
      )
    else
      puts "COMMAND: #{command}"
      puts "STDOUT: #{result[0]}"
      puts "STDERR: #{result[1]}"
      puts "STATUS_CODE: #{result[2]}"
    end
  end
  OpenStruct.new(
    stdout: result[0],
    stderr: result[1],
    exit_code: result[2],
  )
end

class Helper
  include PuppetLitmus
  include BoltSpec
  include Singleton
end

def host_by_role(role)
  array_nodes = []
  inventory_hash = Helper.instance.inventory_hash_from_inventory_file
  inventory_hash['groups'].each do |group|
    group['targets'].each do |node|
      if node['vars']['role'] == role
        array_nodes.push(node['uri'])
      end
    end
  end
  array_nodes.first
end

RSpec.configure do |c|
  c.formatter = :documentation
  c.before :suite do
    # build dropsonde gem and install it on puppetserver container
    run_local_command('gem build dropsonde.gemspec')
    ENV['TARGET_HOST'] = host_by_role('puppet')
    Helper.instance.bolt_upload_file("dropsonde-#{Dropsonde::VERSION}.gem", "/root/dropsonde-#{Dropsonde::VERSION}.gem")
    Helper.instance.run_shell("/opt/puppetlabs/puppet/bin/gem install /root/dropsonde-#{Dropsonde::VERSION}.gem")
  end

  # commands suite to run acceptance tests locally
  # bundle install
  # bundle exec rake spec_prep
  # bundle exec bolt plan run dropsonde::provision_postgres --modulepath ./spec/fixtures/modules/
  # bundle exec bolt plan run dropsonde::provision_puppetserver --modulepath ./spec/fixtures/modules/
  # bundle exec bolt plan run dropsonde::provision_puppetdb --modulepath ./spec/fixtures/modules/ --inventory ./spec/fixtures/litmus_inventory.yaml
  # bundle exec bolt plan run dropsonde::provision_agents --modulepath ./spec/fixtures/modules/
  # bundle exec bolt plan run dropsonde::agents_setup --modulepath ./spec/fixtures/modules/ --inventory ./spec/fixtures/litmus_inventory.yaml
  # bundle exec bolt plan run dropsonde::config_infra --modulepath ./spec/fixtures/modules/ --inventory ./spec/fixtures/litmus_inventory.yaml
  # bundle exec rake dropsonde:acceptance
  # bundle exec rake litmus:tear_down
end
