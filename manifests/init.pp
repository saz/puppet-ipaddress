# Class: ipaddress
#
# This module manages ipaddress
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
define ipaddress (
  $device,
  $ipaddr,
  $netmask,
  $ensure = present,
  $family = 'inet', 
  $method = 'static',
  $gateway = undef
) {

  case $::operatingsystem {
    /(Ubuntu|Debian)/: {
      # Device string for augeas
      $cur_device = "iface[. = '${device}'][family='${family}']"
      $cur_device_family = "${cur_device}/family"

      # Set some default values
      Augeas {
        incl => '/etc/network/interfaces',
        lens => 'Interfaces.lns',
      }

      case $ensure {
        present: {
          augeas { "auto-${device}-${family}":
            changes => "set auto[last()+1]/1 ${device}",
            onlyif  => "match auto/* not_include ${device}",
            notify  => Exec["ifup-${device}-${family}"],
          }

          augeas { "iface-${device}-${family}":
            changes => [
              "defnode curdev iface[last()+1] ${device}",
              "set \$curdev/family ${family}",
              "set \$curdev/method ${method}",
            ],
            onlyif  => "get ${cur_device_family} != ${family}",
            require => Augeas["auto-${device}-${family}"],
            notify  => Exec["ifup-${device}-${family}"],
          }

          case $method {
            'static': {
              augeas { "static-${device}-${family}":
                changes => [
                  "set ${cur_device}/address ${ipaddr}",
                  "set ${cur_device}/netmask ${netmask}",
                ],
                require => Augeas["iface-${device}-${family}"],
                notify  => Exec["ifup-${device}-${family}"],
              }

              if $gateway {
                augeas { "gateway-${device}-${family}":
                  context => '/files/etc/network/interfaces',
                  changes => "set ${cur_device}/gateway ${gateway}",
                  require => Augeas["static-${device}"],
                  notify  => Exec["ifup-${device}-${family}"],
                }

                $require_exec = [
                  Augeas["iface-${device}-${family}"],
                  Augeas["gateway-${device}-${family}"],
                ]
              } else {
                $require_exec = Augeas["static-${device}-${family}"]
              }
            }
          }

          exec { "ifup-${device}-${family}":
            command     => "/sbin/ifup --force ${device}",
            require     => $require_exec,
            refreshonly => true,
          }
        }
      }
    }
  }
}
