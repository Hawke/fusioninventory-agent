package FusionInventory::Agent::SNMP;

use strict;
use warnings;
use Encode qw(encode);

sub new {
   my ( undef, $params ) = @_;

   my $self = {};

   if ( not eval { require Net::SNMP; 1 } ) {
      $self->{logger}->debug("Can't load Net::SNMP. Exiting...");
      exit(0);
   }

   my $session = $self->{SNMPSession} = $params->{config};
   my $SNMPVersion;
   if ($params->{version} eq '1') {
      $SNMPVersion = 'snmpv1';
   } elsif ($params->{version} eq '2c') {
      $SNMPVersion = 'snmpv2c';
   } elsif ($params->{version} eq '3') {
      $SNMPVersion = 'snmpv3';
   }
   my $version = $self->{SNMPSession}->{version} = $SNMPVersion;
   my $hostname = $self->{SNMPSession}->{hostname} = $params->{hostname};
   my $community = $self->{SNMPSession}->{community} = $params->{community};
   my $username = $self->{SNMPSession}->{username} = $params->{username};
   my $authpassword = $self->{SNMPSession}->{authpassword} = $params->{authpassword};
   my $authprotocol = $self->{SNMPSession}->{authprotocol} = $params->{authprotocol};
   my $privpassword = $self->{SNMPSession}->{privpassword} = $params->{privpassword};
   my $privprotocol = $self->{SNMPSession}->{privprotocol} = $params->{privprotocol};
   if ($params->{translate} eq '0') {
      my $translate = $self->{SNMPSession}->{translate} = '-all';
   } elsif ($params->{translate} eq '1') {
      my $translate = $self->{SNMPSession}->{translate} = '-octetstring';
   }

   if ($version eq 'snmpv3') {
      if($privprotocol =~ /hash/i){
         ($self->{SNMPSession}->{session}, $self->{SNMPSession}->{error}) = Net::SNMP->session(
               -timeout   => 1,
               -retries   => 0,
               -hostname     => $hostname,
               -version      => $version,
               -username     => $username,
               -authpassword => $authpassword,
               -authprotocol => $authprotocol,
               -nonblocking => 0,
               #-translate   => [$translate => 0],
               -port      => 161
         );
      } else {
         ($self->{SNMPSession}->{session}, $self->{SNMPSession}->{error}) = Net::SNMP->session(
               -timeout   => 1,
               -retries   => 0,
               -hostname     => $hostname,
               -version      => $version,
               -username     => $username,
               -authpassword => $authpassword,
               -authprotocol => $authprotocol,
               -privpassword => $privpassword,
               -privprotocol => $privprotocol,
               -nonblocking => 0,
              # -translate   => [$translate => 0],
               -port      => 161
         );

      }
   } else { # snmpv2c && snmpv1 #
      ($self->{SNMPSession}->{session}, $self->{SNMPSession}->{error}) = Net::SNMP->session(
         -version   => $version,
         -timeout   => 1,
         -retries   => 0,
         -hostname  => $hostname,
         -community => $community,
         -nonblocking => 0,
         #-translate   => [$translate => 0],
         -port      => 161
      );
   }

   bless $self;
}


sub snmpGet {
   my ($self, $args) = @_;

   my $oid = $args->{oid};
   my $up = $args->{up};

   my $session = $self->{SNMPSession}->{session};

   my $result = $session->get_request(
      -varbindlist => [$oid]
   );
   my $return;
   if (!defined($result)) {
      my $err = $self->{SNMPSession}->{session}->error;
      #debug($log,"[".$_[1]."] Error : ".$err,"",$PID);
      if ((defined $up) && ($up == 1)) {
         $return = "No response from remote host";
      } else {
         $return = "null";
      }
   } else {
      if ($result->{$oid} =~ /noSuchInstance/) {
         $return = "null";
      } else {
         if ($oid =~ /No response from remote host/) {
            $return = "null";
         } else {
            if ($oid =~ /.1.3.6.1.2.1.17.4.3.1.1/) {
               $result->{$oid} = getBadMACAddress($oid,$result->{$oid});
            }
            if ($oid =~ /.1.3.6.1.2.1.17.1.1.0/) {
               $result->{$oid} = getBadMACAddress($oid,$result->{$oid});
            }
            if ($oid =~ /.1.3.6.1.2.1.2.2.1.6/) {
               $result->{$oid} = getBadMACAddress($oid,$result->{$oid});
            }
            if ($oid =~ /.1.3.6.1.2.1.4.22.1.2/) {
               $result->{$oid} = getBadMACAddress($oid,$result->{$oid});
            }
            if ($oid =~ /.1.3.6.1.4.1.9.9.23.1.2.1.1.4/) {
               $result->{$oid} = getBadMACAddress($oid,$result->{$oid});
            }
            $result->{$oid} = specialChar($result->{$oid});
            $result->{$oid} =~ s/\n$//;
            $return = $result->{$oid};
         }
      }
   }
   return $return;
}


sub snmpWalk {
   my ($self, $args) = @_;

   my $oid_start = $args->{oid_start};

   my $ArraySNMP = {};

   my $oid_prec = $oid_start;
   if (defined($oid_start)) {
      while($oid_prec =~ m/$oid_start/) {
         my $response = $self->{SNMPSession}->{session}->get_next_request($oid_prec);
         my $err = $self->{SNMPSession}->{session}->error;
         if ($err){
            #debug($log,"[".$_[1]."] Error : ".$err,"",$PID);
            #debug($log,"[".$_[1]."] Oid Error : ".$oid_prec,"",$PID);
            return $ArraySNMP;
         }
         my %pdesc = %{$response};
         #print %pdesc;
         while ((my $object,my $oid) = each (%pdesc))
         {
            if ($object =~ /$oid_start/)
            {
               if ($oid !~ /No response from remote host/) {
                  if ($object =~ /.1.3.6.1.2.1.17.4.3.1.1/) {
                     $oid = getBadMACAddress($object,$oid)
                  }
                  if ($object =~ /.1.3.6.1.2.1.17.1.1.0/) {
                     $oid = getBadMACAddress($object,$oid)
                  }
                  if ($object =~ /.1.3.6.1.2.1.2.2.1.6/) {
                     $oid = getBadMACAddress($object,$oid)
                  }
                  if ($object =~ /.1.3.6.1.2.1.4.22.1.2/) {
                     $oid = getBadMACAddress($object,$oid)
                  }
                  if ($object =~ /.1.3.6.1.4.1.9.9.23.1.2.1.1.4/) {
                     $oid = getBadMACAddress($object,$oid)
                  }
                  my $object2 = $object;
                  $object2 =~ s/$_[0].//;
                  $oid = specialChar($oid);
                  $oid =~ s/\n$//;
                  $ArraySNMP->{$object2} = $oid;
               }
            }
            $oid_prec = $object;
         }
      }
   }
   return $ArraySNMP;
}



sub specialChar {
   if (defined($_[0])) {
      if ($_[0] =~ /0x$/) {
         return "";
      }
      $_[0] = encode('UTF-8', $_[0]);
      $_[0] =~ s/\0//g;
      $_[0] =~ s/([\x80-\xFF])//g;
      return $_[0];
   } else {
      return "";
   }
}


sub getBadMACAddress {
   my $OID_ifTable = shift;
   my $oid_value = shift;

   if ($oid_value !~ /0x/) {
      $oid_value = "0x".unpack 'H*', $oid_value;
   }

   my @array = split(/(\S{2})/, $oid_value);
   if (@array eq "14") {
      $oid_value = $array[3].":".$array[5].":".$array[7].":".$array[9].":".$array[11].":".$array[13];
   }
   return $oid_value;
}


1;