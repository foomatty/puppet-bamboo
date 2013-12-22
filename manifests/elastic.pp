# Class: elastic
#
# This module manages Atlassian Bamboo
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
# [Remember: No empty lines between comments and class definition]
class bamboo::elastic (
  $version = '3.0',
  $extension = 'zip',
  $installdir = '/opt/bamboo-elastic-agent',
  $home = '/home/bamboo',
  $user = 'bamboo'){

  $srcdir = '/opt'

  File {
    owner  => $user,
    group  => $user,
  }

  if !defined(User[$user]) {
    user { $user:
      ensure     => present,
      home       => $home,
      managehome => false,
      system     => false,
      shell      => '/bin/bash',
    }
  }
  exec { "enable-$user-sudo-requiretty" :
    command => "/bin/echo 'Defaults:$user !requiretty' >> /etc/sudoers",
    unless  => "/bin/grep 'Defaults:$user !requiretty' /etc/sudoers",
  }
  exec { "enable-$user-sudo-securepath" :
    command => "/bin/echo 'Defaults:$user secure_path = /usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin' >> /etc/sudoers",
    unless  => "/bin/grep 'Defaults:$user secure_path = /usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin' /etc/sudoers",
  }
  $adminGroup = $lsbdistrelease ? {
    '11.04'  => 'admin',
    '12.04' => 'sudo',
    default  => 'sudo',
  }
  exec { "add $user to sudo group" :
    command => "/usr/sbin/usermod -a -G $adminGroup $user",
    unless  => "/bin/egrep $adminGroup.+$user /etc/group",
    require => User["$user"],
  }
  file { $installdir : ensure => directory } ->
  exec { 'get-bamboo-agent':
    cwd     => "${srcdir}",
    command => "/usr/bin/wget http://maven.atlassian.com/content/repositories/atlassian-public/com/atlassian/bamboo/atlassian-bamboo-agent-elastic-assembly/3.0/atlassian-bamboo-agent-elastic-assembly-${version}.${extension}",
    unless  => "/usr/bin/test -f ${srcdir}/atlassian-bamboo-elastic-image-${version}.${extension}",
  } ->
  exec { 'bamboo':
    command => "unzip -o ${srcdir}/atlassian-bamboo-elastic-image-${version}.${extension} -d ${installdir}",
    creates => "${installdir}/bin",
    cwd     => $installdir,
    logoutput => "on_failure",
    path    => '/bin:/usr/bin',
  } ->
  file { $home:
    ensure => directory,
  } ->
  file { "${home}/logs":
    ensure => directory,
  } ->
  file { '/etc/default/bamboo':
    ensure  => present,
    content => "RUN_AS_USER=${user}
BAMBOO_PID=${home}/bamboo.pid
BAMBOO_LOG_FILE=${home}/logs/bamboo.log",
  } ~>
  exec { "start-bamboo-elastic" :
    command => "su -c /opt/bamboo-elastic-agent/bin/bamboo-elastic-agent - bamboo &",
    path    => "/bin:/usr/bin",
    unless  => "/bin/ps -ef|/bin/grep '/opt/bamboo-elastic-agent/bin/bamboo-elastic-agent'|grep -v grep";
  }
}
