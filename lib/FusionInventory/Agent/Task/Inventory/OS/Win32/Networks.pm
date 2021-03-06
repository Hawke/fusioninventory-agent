package FusionInventory::Agent::Task::Inventory::OS::Win32::Networks;


use strict;
use Win32::OLE qw(in CP_UTF8);
use Win32::OLE::Const;
 
Win32::OLE-> Option(CP=>CP_UTF8);


use Win32::OLE::Enum;

use FusionInventory::Agent::Task::Inventory::OS::Win32;

# http://techtasks.com/code/viewbookcode/1417
sub isInventoryEnabled {1}

sub doInventory {
    my $params = shift;
    my $inventory = $params->{inventory};

    my $strComputer = '.';
    my $objWMIService = Win32::OLE->GetObject('winmgmts:' . '{impersonationLevel=impersonate}!\\\\' . $strComputer . '\\root\\cimv2');

    my $nics = $objWMIService->ExecQuery('SELECT * FROM Win32_NetworkAdapterConfiguration');

    my @ips;
    my @ip6s;
    my @netifs;
    foreach my $nic (in $nics) {
        my $idx = $nic->Index;
        $netifs[$idx]{description} =  encodeFromWmi($nic->Description);
        $netifs[$idx]{ipaddress} = [];
        $netifs[$idx]{ipsubnet} = [];
        $netifs[$idx]{ipmask} = [];
        $netifs[$idx]{ipaddress6} = [];
        $netifs[$idx]{ipsubnet6} = [];
        $netifs[$idx]{ipmask6} = [];

        if ($nic->IPAddress) {
            foreach (0..@{$nic->IPAddress}) {
                if (${$nic->IPAddress}[$_] =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) {
                    push @ips, ${$nic->IPAddress}[$_];
                    push @{$netifs[$idx]{ipaddress}}, ${$nic->IPAddress}[$_];
                    push @{$netifs[$idx]{ipmask}}, ${$nic->IPSubnet}[$_];
                    if (can_load("Net::IP qw(:PROC)")) {
                        my $binip = ip_iptobin (${$nic->IPAddress}[$_] , 4);
                        my $binmask = ip_iptobin (${$nic->IPSubnet}[$_] , 4);
                        my $binsubnet = $binip & $binmask;
                        push @{$netifs[$idx]{ipsubnet}}, ip_bintoip($binsubnet, 4);
                    }
                } elsif (${$nic->IPAddress}[$_] =~ /\S+/) {
                    push @ip6s, ${$nic->IPAddress}[$_];
                    push @{$netifs[$idx]{ipaddress6}}, ${$nic->IPAddress}[$_];
                    push @{$netifs[$idx]{ipmask6}}, ${$nic->IPSubnet}[$_];
                    if (can_load("Net::IP qw(:PROC)")) {
                        my $binip = ip_iptobin (${$nic->IPAddress}[$_] , 6);
                        my $binmask = ip_iptobin (${$nic->IPSubnet}[$_] , 6);
                        my $binsubnet = $binip & $binmask;
                        push @{$netifs[$idx]{ipsubnet6}}, 
ip_bintoip($binsubnet, 6);
                    }
                }
            }
        }

        if ($nic->DefaultIPGateway) {
            $netifs[$idx]{ipgateway} = $nic->DefaultIPGateway()->[0];
        }

        $netifs[$idx]{status} = $nic->IPEnabled?"Up":"Down";
        $netifs[$idx]{name} = $nic->Name;
        $netifs[$idx]{ipdhcp} = $nic->DHCPServer;
        $netifs[$idx]{macaddr} = $nic->MACAddress;
        $netifs[$idx]{mtu} = $nic->MTU;
    }

    $nics = $objWMIService->ExecQuery('SELECT * FROM Win32_NetworkAdapter');
    foreach my $nic (in $nics) {
        my $idx = $nic->Index;
        $netifs[$idx]{virtualdev} = $nic->PhysicalAdapter?0:1;
        $netifs[$idx]{name} = $nic->Name;
        $netifs[$idx]{macaddr} = $nic->MACAddress;
        $netifs[$idx]{speed} = $nic->Speed;
    }

    foreach my $netif (@netifs) {

        my $ipaddress;
        my $ipmask;
        my $ipsubnet;
        my $ipaddress6;


        if ($netif->{ipaddress}) {
            $ipaddress = join('/', @{$netif->{ipaddress}});
        }
        if ($netif->{ipmask}) {
            $ipmask = join('/', @{$netif->{ipmask}});
        } 
        if ($netif->{ipsubnet}) {
            $ipsubnet = join('/', @{$netif->{ipsubnet}});
        }
        if ($netif->{ipaddress6}) {
            $ipaddress6 = join('/', @{$netif->{ipaddress6}});
        }

        $inventory->addNetwork({
                DESCRIPTION => $netif->{description},
                IPADDRESS => $ipaddress,
                IPDHCP => $netif->{ipdhcp},
                IPGATEWAY => $netif->{ipgateway},
                IPMASK => $ipmask,
                IPSUBNET => $ipsubnet,
                IPADDRESS6 => $ipaddress6,
                MACADDR => $netif->{macaddr},
                MTU => $netif->{mtu},
                STATUS => $netif->{status},
                TYPE => $netif->{type},
                VIRTUALDEV => $netif->{virtualdev}
            });

  $inventory->setHardware({

          IPADDR =>  join('/',@ips),
#      SWAP =>    sprintf("%i", $SwapFileSize/1024),

    });


    }
}
1;
