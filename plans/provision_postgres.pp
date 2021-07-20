plan dropsonde::provision_postgres(
  Optional[String] $using = 'docker_exp',
  Optional[String] $image = 'postgres:14beta2-buster',
) {
  if $using == 'docker_exp' {
    $env_vars = "'-e', 'POSTGRES_USER=puppetdb', '-e', 'POSTGRES_PASSWORD=puppetdb', '-e', 'POSTGRES_HOST_AUTH_METHOD=trust'"
    run_task(
      "provision::${using}",
      'localhost',
      action => 'provision',
      platform => $image,
      vars => "role: postgres\ndocker_run_opts: ['--hostname', 'postgres', ${env_vars}]"
    )
  } else {
    run_task(
      "provision::${using}",
      'localhost',
      action => 'provision',
      platform => $image,
      vars => 'role: postgres'
    )
  }
}
