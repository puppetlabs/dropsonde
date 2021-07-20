plan dropsonde::config_infra() {
  $puppetserver = get_targets('*').filter |$n| { $n.vars['role'] == 'puppet' }
  $postgres = get_targets('*').filter |$n| { $n.vars['role'] == 'postgres' }
  $puppetdb = get_targets('*').filter |$n| { $n.vars['role'] == 'puppetdb' }
  $agent1 = get_targets('*').filter |$n| { $n.vars['role'] == 'agent1' }
  $agent2 = get_targets('*').filter |$n| { $n.vars['role'] == 'agent2' }

  $postgres_ip = run_command("getent hosts postgres | awk '{ print \$1 }'", $postgres).to_data[0]['value']['stdout'].strip()
  $puppetserver_ip = run_command('facter networking.interfaces.eth0.ip', $puppetserver).to_data[0]['value']['stdout'].strip()
  $puppetdb_ip = run_command('facter networking.interfaces.eth0.ip', $puppetdb).to_data[0]['value']['stdout'].strip()

  $puppetdb_conf = file('dropsonde/puppetdb.conf')
  $routes_yaml = file('dropsonde/routes.yaml')
  $r10k_yaml = file('dropsonde/r10k.yaml')

  [$agent1, $agent2].each |$agent| {
    $hostname = run_command('facter hostname', $agent).to_data[0]['value']['stdout'].strip()
    $agent_ip = run_command('facter networking.interfaces.eth0.ip', $agent).to_data[0]['value']['stdout'].strip()
    run_command("echo '${agent_ip} ${hostname}' >> /etc/hosts", $puppetserver)
    run_command("echo '${puppetserver_ip} puppet' >> /etc/hosts", $agent)
    run_command("echo '${puppetdb_ip} puppetdb' >> /etc/hosts", $agent)
    run_command('/opt/puppetlabs/bin/puppet resource package puppetdb-termini ensure=latest', $agent)
    apply($agent, '_description' => 'config puppetdb') {
      file { '/etc/puppetlabs/puppet/puppetdb.conf':
        ensure  => present,
        content => $puppetdb_conf,
        mode    => '0666',
      }
      file { '/etc/puppetlabs/puppet/routes.yaml':
        ensure  => present,
        content => $routes_yaml,
        mode    => '0666',
      }
    }
  }

  run_command("echo '${puppetdb_ip} puppetdb' >> /etc/hosts", $puppetserver)
  run_command("echo '${postgres_ip} postgres' >> /etc/hosts", $puppetserver)

  ctrl::sleep(240)

  run_command('/opt/puppetlabs/bin/puppet agent -t', [$agent1, $agent2], '_catch_errors' => true)

  apply($puppetserver, '_description' => 'config r10k') {
    file { '/etc/puppetlabs/r10k':
      ensure => directory,
    }
    file { '/etc/puppetlabs/r10k/r10k.yaml':
      ensure  => present,
      content => $r10k_yaml,
      mode    => '0666',
      require => File['/etc/puppetlabs/r10k'],
    }
  }

  run_command('r10k deploy environment -p', $puppetserver)

  run_command('/opt/puppetlabs/bin/puppet agent -t', [$agent1, $agent2], '_catch_errors' => true)
}
