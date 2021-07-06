# frozen_string_literal: true

require 'yaml'
require 'open3'
require 'ostruct'
require 'tempfile'

def run_shell(command, opts = {})
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

def setup
  postgres = [
    'docker run -d -it',
    '-e POSTGRES_USER=puppetdb',
    '-e POSTGRES_PASSWORD=puppetdb',
    '-e POSTGRES_HOST_AUTH_METHOD=trust',
    '--hostname postgres',
    '--name postgres',
    'postgres:14beta2-buster',
  ].join(' ')
  run_shell(postgres)

  puppetserver = 'docker run -d -it --hostname puppet --name puppet puppet/puppetserver'
  run_shell(puppetserver)

  postgres_ip = run_shell('docker inspect postgres --format="{{ .NetworkSettings.IPAddress }}"').stdout.delete("\n")
  puppetserver_ip = run_shell('docker inspect puppet --format="{{ .NetworkSettings.IPAddress }}"').stdout.delete("\n")
  puppetdb = [
    'docker run -d -it',
    '--link postgres:postgres',
    '--link puppet:puppet',
    "-e PUPPETDB_POSTGRES_HOSTNAME=#{postgres_ip}",
    "-e PUPPETSERVER_HOSTNAME=#{puppetserver_ip}",
    '--name puppetdb',
    '--hostname puppetdb',
    'puppet/puppetdb',
  ].join(' ')

  run_shell(puppetdb)
end

def agent_run(target)
  run_shell("docker exec #{target} /opt/puppetlabs/bin/puppet agent -t")
end

def create_file_to_container(id, content, path)
  Tempfile.create do |file|
    file << content
    file.rewind
    run_shell("docker cp #{file.path} #{id}:#{path}")
  end
end

RSpec.configure do |c|
  c.before :suite do
    puppetdb_conf = <<-HEREDOC
[main]
server_urls = https://puppetdb:8081/
soft_write_failure = false
HEREDOC
    routes_yaml = <<-YAML
---
apply:
  catalog:
    terminus: compiler
    cache: puppetdb
  resource:
    terminus: ral
    cache: puppetdb
  facts:
    terminus: facter
    cache: puppetdb_apply
YAML
    r10k_yaml = <<-YAML
:cachedir: '/var/cache/r10k'
:sources:
  :my-org:
    remote: 'https://github.com/adrianiurca/simple_control_repo.git'
    basedir: '/etc/puppetlabs/code/environments'
YAML
    # start puppetserver, puppetdb and postgres containers
    setup

    # get ips
    postgres_ip = run_shell('docker inspect postgres --format="{{ .NetworkSettings.IPAddress }}"').stdout.delete("\n")
    puppetdb_ip = run_shell('docker inspect puppetdb --format="{{ .NetworkSettings.IPAddress }}"').stdout.delete("\n")
    server_ip = run_shell('docker inspect puppet --format="{{ .NetworkSettings.IPAddress }}"').stdout.delete("\n")
    server_id = run_shell('docker inspect puppet --format="{{ .Id }}"').stdout.delete("\n")

    # config agent nodes
    containers = run_shell('docker ps --format="{{ .Names }}"').stdout.split("\n")
    containers.select { |container| container.start_with?('litmusimage') }.each do |container|
      id = run_shell("docker inspect #{container} --format='{{ .Id }}'").stdout.delete("\n")
      hostname = run_shell("docker inspect #{container} --format='{{ .Config.Hostname }}'").stdout.delete("\n")
      ip = run_shell("docker inspect #{container} --format='{{ .NetworkSettings.IPAddress }}'").stdout.delete("\n")
      run_shell("docker exec puppet bash -c \"echo '#{ip} #{hostname}' >> /etc/hosts\"")
      run_shell("docker exec #{container} bash -c \"echo '#{server_ip} puppet' >> /etc/hosts\"")
      run_shell("docker exec #{container} bash -c \"echo '#{puppetdb_ip} puppetdb' >> /etc/hosts\"")
      run_shell("docker exec #{container} /opt/puppetlabs/bin/puppet resource package puppetdb-termini ensure=latest")
      create_file_to_container(id, puppetdb_conf, '/etc/puppetlabs/puppet/puppetdb.conf')
      create_file_to_container(id, routes_yaml, '/etc/puppetlabs/puppet/routes.yaml')
      run_shell("docker exec #{container} chmod +r /etc/puppetlabs/puppet/puppetdb.conf")
      run_shell("docker exec #{container} chmod +r /etc/puppetlabs/puppet/routes.yaml")
    end

    # set puppetdb and postgres hosts on puppetserver container
    run_shell("docker exec puppet bash -c \"echo '#{puppetdb_ip} puppetdb' >> /etc/hosts\"")
    run_shell("docker exec puppet bash -c \"echo '#{postgres_ip} postgres' >> /etc/hosts\"")

    # wait until puppetserver is up and running
    sleep 240

    # link the nodes with puppetserver and puppetdb
    agent_run('litmusimage_centos_7-2222')
    agent_run('litmusimage_debian_9-2223')

    # config r10k
    run_shell('docker exec puppet mkdir /etc/puppetlabs/r10k')
    create_file_to_container(server_id, r10k_yaml, '/etc/puppetlabs/r10k/r10k.yaml')
    run_shell('docker exec puppet chmod +r /etc/puppetlabs/r10k/r10k.yaml')

    # deploy simple_control_repo from github
    run_shell('docker exec puppet r10k deploy environment -p')

    # apply the infrastructure defined in simple_control_repo.git
    agent_run('litmusimage_centos_7-2222')
    agent_run('litmusimage_debian_9-2223')

    # build dropsonde gem and install it on puppetserver container
    run_shell('gem build dropsonde.gemspec')
    run_shell("docker cp dropsonde-#{Dropsonde::VERSION}.gem #{server_id}:/root/dropsonde-#{Dropsonde::VERSION}.gem")
    run_shell("docker exec puppet /opt/puppetlabs/puppet/bin/gem install /root/dropsonde-#{Dropsonde::VERSION}.gem")
  end
end
