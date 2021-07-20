plan dropsonde::provision_agents(
  Optional[String] $using = 'docker_exp',
  Optional[Array[String]] $images = ['litmusimage/centos:7', 'litmusimage/debian:9']
) {
  # provision machines, set roles
  $image_index = 0
  [0, 1].each |$index| {
    $hostname_count = $index + 1
    run_task(
      "provision::${using}",
      'localhost',
      action => 'provision',
      platform => $images[$index],
      vars => "role: agent${hostname_count}\ndocker_run_opts: ['--hostname', 'agent${hostname_count}']"
    )
  }
}
