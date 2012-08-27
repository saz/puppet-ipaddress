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
      $cur_device_method = "${cur_device}/method"

      # Set some default values
      Augeas {
        incl   => '/etc/network/interfaces',
        lens   => 'Interfaces.lns',
        notify => Exec["ifup-${device}-${family}"],
      }

      case $ensure {
        present: {
          augeas { "auto-${device}-${family}":
            changes => "set auto[child::1 = '${device}']/1 ${device}",
            onlyif  => "match auto/* not_include ${device}",
          }

          augeas { "iface-${device}-${family}":
            changes => [
              "set iface[last()+1] ${device}",
              "set iface[last()]/family ${family}",
              "set iface[last()]/method ${method}",
            ],
            onlyif  => "get iface[.='${device}'][family='${family}'][method='${method}'] != ${device}",
            require => Augeas["auto-${device}-${family}"],
          }

          case $method {
            'static': {
              augeas { "static-${device}-${family}":
                changes => [
                  "set ${cur_device}/address ${ipaddr}",
                  "set ${cur_device}/netmask ${netmask}",
                ],
                require => Augeas["iface-${device}-${family}"],
              }

              if $gateway {
                augeas { "gateway-${device}-${family}":
                  changes => "set ${cur_device}/gateway ${gateway}",
                  require => Augeas["static-${device}-${family}"],
                }

                $require_exec = [
                  Augeas["iface-${device}-${family}"],
                  Augeas["gateway-${device}-${family}"],
                ]
              } else {
                $require_exec = Augeas["static-${device}-${family}"]
              }
            }
            default: {
              fail("Method ${method} not implemented")
            }
          }

          exec { "ifup-${device}-${family}":
            command     => "/sbin/ifup --force ${device}",
            require     => $require_exec,
            refreshonly => true,
          }
        }
        default: {
          fail('ensure must be set to present')
        }
      }
    }
  }
}
