plan dropsonde::provision_puppetdb(
  Optional[String] $using = 'docker_exp',
  Optional[String] $image = 'puppet/puppetdb',
) {
  if $using == 'docker_exp' {
    $puppetserver = get_targets('*').filter |$n| { $n.vars['role'] == 'puppet' }
    $postgres = get_targets('*').filter |$n| { $n.vars['role'] == 'postgres' }
    $puppetserver_ip = run_command('facter networking.interfaces.eth0.ip', $puppetserver).to_data[0]['value']['stdout'].strip()
    $postgres_ip = run_command("getent hosts postgres | awk '{ print \$1 }'", $postgres).to_data[0]['value']['stdout'].strip()
    $env_vars = "'-e', 'PUPPETDB_POSTGRES_HOSTNAME=${postgres_ip}', '-e', 'PUPPETSERVER_HOSTNAME=${puppetserver_ip}'"
    run_task(
      "provision::${using}",
      'localhost',
      action => 'provision',
      platform => $image,
      vars => "role: puppetdb\ndocker_run_opts: ['--hostname', 'puppetdb', ${env_vars}]"
    )
  } else {
    run_task(
      "provision::${using}",
      'localhost',
      action => 'provision',
      platform => $image,
      vars => 'role: puppet'
    )
  }
}
