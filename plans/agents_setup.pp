plan dropsonde::agents_setup(
  Optional[String] $collection = 'puppet7'
) {
  # get agents and puppet server
  $agents = get_targets('*').filter |$n| { $n.vars['role'] == 'agent1' or $n.vars['role'] == 'agent2' }

  # install agents
  run_task('puppet_agent::install', $agents, { 'collection' => $collection })

  run_task('puppet_conf', $agents, action => 'set', section => 'main', setting => 'server', value => 'puppet')

  catch_errors() || {
    run_command('systemctl start puppet', $agents, '_catch_errors' => true)
    run_command('systemctl enable puppet', $agents, '_catch_errors' => true)
  }
}
