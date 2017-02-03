# Internal class - manage JBoss service
class jboss::internal::refresh_deploy {

  include jboss
  include jboss::params
  include jboss::internal::configuration
  include jboss::internal::params

  Exec {
    path      => $jboss::internal::params::syspath,
    logoutput => 'on_failure',
  }

  $servicename = $jboss::product
  # TODO: change to $::virtual after dropping support for Puppet 2.x
  $enable = $::jboss_virtual ? {
    'docker' => undef,
    default  => true,
  }

  exec { 'jboss::service::test-running_refresh_deploy':
    loglevel  => 'emerg',
    command   => "tail -n 50 ${jboss::internal::configuration::logfile} && exit 1",
    unless    => "ps aux | grep ${servicename} | grep -vq grep",
    logoutput => true,
    subscribe => Service[$servicename],
  }

  exec { 'jboss::service::restart_refresh_deploy':
    command     => "service ${servicename} stop ; pkill -9 -f \"^java.*jboss\"  ; service ${servicename} start",
    refreshonly => true,
    require     => Exec['jboss::service::test-running_refresh_deploy'],
  }

}
