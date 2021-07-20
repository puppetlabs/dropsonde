plan dropsonde::provision_puppetserver(
  Optional[String] $using = 'docker_exp',
  Optional[String] $image = 'puppet/puppetserver',
) {
  if $using == 'docker_exp' {
    run_task(
      "provision::${using}",
      'localhost',
      action => 'provision',
      platform => $image,
      vars => "role: puppet\ndocker_run_opts: ['--hostname', 'puppet']"
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
