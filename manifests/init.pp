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
define ipaddress (  $device, $ipaddr, $netmask, $up = true,
                    $ensure = present, $onboot = true, $family = 'inet', 
					$method = 'static', hwaddr = false, $network = false,
					$gateway = false) {

    case $::operatingsystem {
        /(Ubuntu|Debian)/: {
			# Device string for augeas
            $cur_device = "iface[. = '${device}']"

			if $ensure == 'present' {
				if $onboot {
					augeas { "auto-${device}":
						context => '/files/etc/network/interfaces',
						changes => "set auto[child::1 = '${device}']/1 ${device}",
					}
				}

				augeas { "common-${device}":
					context => '/files/etc/network/interfaces',
					changes => [
						"set ${cur_device} ${device}",
						"set ${cur_device}/family ${family}",
						"set ${cur_device}/method ${method}",
					],
					require => $onboot ? {
						true => Augeas["auto-${device}"],
					},
				}

				case $method {
					'static': {
						augeas { "address-${device}":
							context => '/files/etc/network/interfaces',
							changes => [
								"set ${cur_device}/address ${ipaddr}",
								"set ${cur_device}/netmask ${netmask}",
							],
							require => Augeas["common-${device}"],
						}
					}
				}

				if $hwaddr {
					augeas { "mac-${device}":
						context => '/files/etc/network/interfaces',
						changes => "set ${cur_device}/hwaddress ${hwaddr}",
						require => Augeas["common-${device}"],
					}
				}

				if $network {
					augeas { "network-${device}":
						context => '/files/etc/network/interfaces',
						changes => "set ${cur_device}/network ${network}",
						require => Augeas["common-${device}"],
					}
				}

				if $gateway {
					augeas { "gateway-${device}":
						context => '/files/etc/network/interfaces',
						changes => "set ${cur_device}/gateway ${gateway}",
						require => Augeas["common-${device}"],
					}
				}

				if $up {
					exec { "ifup-${device}":
						command => "/sbin/ifup ${device}",
						unless  => "/sbin/ifconfig | grep ${device}",
						require => Augeas["common-${device}"],
					}
				} else {
					exec { "ifdown-${device}":
						command => "/sbin/ifdown ${device}",
						onlyif => "/sbin/ifconfig | grep ${device}",
					}
				}
			} else {
				exec { "ifdown-${device}":
					command => "/sbin/ifdown ${device}",
					onlyif => "/sbin/ifconfig | grep ${device}",
				}

				augeas { "remove-${device}":
					context => '/files/etc/network/interfaces',
					changes => [
						"rm ${cur_device}",
						"rm auto[child::1 = '${device}']",
					],
					require => Exec["ifdown-${device}"],
				}
			}
        }
    }
}
