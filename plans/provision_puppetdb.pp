plan dropsonde::provision_puppetdb(
  Optional[String] $using = 'docker_exp',
  Optional[String] $image = 'puppet/puppetdb',
) {
  if $using == 'docker_exp' {
    $puppetserver = get_targets('*').filter |$n| { $n.vars['role'] == 'puppet' }
    $postgres = get_targets('*').filter |$n| { $n.vars['role'] == 'postgres' }
    $puppetserver_ip = run_command('facter networking.interfaces.eth0.ip', $puppetserver).to_data[0]['value']['stdout'].strip()
    $postgres_ip = run_command("getent hosts postgres | awk '{ print \$1 }'", $postgres).to_data[0]['value']['stdout'].strip()
    $puppetserver_id = facts($puppetserver[0])['container_id']
    $postgres_id = facts($postgres[0])['container_id']
    $env_vars = "'-e', 'PUPPETDB_POSTGRES_HOSTNAME=${postgres_ip}', '-e', 'PUPPETSERVER_HOSTNAME=${puppetserver_ip}'"
    $links = "'--link', '${postgres_id}:postgres', '--link', '${puppetserver_id}:puppet'"
    run_task(
      "provision::${using}",
      'localhost',
      action => 'provision',
      platform => $image,
      vars => "role: puppetdb\ndocker_run_opts: ['--hostname', 'puppetdb', ${env_vars}, ${links}]"
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
