plan dropsonde::agents_setup(
  Optional[String] $collection = 'puppet7'
) {
  # get agents ?
  $agents = get_targets('*').filter |$n| { $n.vars['role'] == 'agent' }

  # install agents
  run_task('puppet_agent::install', $agents, { 'collection' => $collection })

  $server_fqdn = 'puppet'
  run_task('puppet_conf', $agents, action => 'set', section => 'main', setting => 'server', value => $server_fqdn)

  catch_errors() || {
    run_command('systemctl start puppet', $agents, '_catch_errors' => true)
    run_command('systemctl enable puppet', $agents, '_catch_errors' => true)
  }
}
