package FusionInventory::Agent::Task::Inventory::OS::Win32::Bios;

use FusionInventory::Agent::Task::Inventory::OS::Win32;

use strict;

use Win32::TieRegistry ( Delimiter=>"/", ArrayValues=>0 );

sub isInventoryEnabled {1}

sub getBiosInfoFromRegistry {
    my $KEY_WOW64_64KEY = 0x100; 

    my $machKey= $Registry->Open( "LMachine", {Access=>Win32::TieRegistry::KEY_READ()|$KEY_WOW64_64KEY,Delimiter=>"/"} );

    my $data =
        $machKey->{"Hardware/Description/System/BIOS"};

    my $info;

    foreach my $tmpkey (%$data) {
        next unless $tmpkey =~ /^\/(.*)/;
        my $key = $1;

        $info->{$key} = $data->{$tmpkey};
    }

    return $info;
}




sub doInventory {
    my $params = shift;
    my $inventory = $params->{inventory};

    my $smodel;
    my $smanufacturer;
    my $ssn;
    my $enclosureSerial;
    my $baseBoardSerial;
    my $biosSerial;
    my $bdate;
    my $bversion;
    my $bmanufacturer;
    my $mmanufacturer;
    my $msn;
    my $model;
    my $assettag;


    my $registryInfo = getBiosInfoFromRegistry();

    $bdate = $registryInfo->{BIOSReleaseDate};

    foreach my $Properties
        (getWmiProperties('Win32_Bios',
qw/SerialNumber Version Manufacturer SMBIOSBIOSVersion BIOSVersion/)) {
        $biosSerial = $Properties->{SerialNumber};
        $ssn = $Properties->{SerialNumber} unless $ssn;
        $bmanufacturer = $Properties->{Manufacturer} unless $bmanufacturer;
        $bversion = $Properties->{SMBIOSBIOSVersion} unless $bversion;
        $bversion = $Properties->{BIOSVersion} unless $bversion;
        $bversion = $Properties->{Version} unless $bversion;
    }

    foreach my $Properties
        (getWmiProperties('Win32_ComputerSystem',
qw/Manufacturer Model/)) {

        $smanufacturer = $Properties->{Manufacturer} unless $smanufacturer;
        $model = $Properties->{Model} unless $model;

    }

    foreach my $Properties
        (getWmiProperties('Win32_SystemEnclosure',
qw/SerialNumber SMBIOSAssetTag/)) {

        $enclosureSerial = $Properties->{SerialNumber} ;
        $ssn = $Properties->{SerialNumber} unless $ssn;
        $assettag = $Properties->{SMBIOSAssetTag} unless $assettag;

    }

    foreach my $Properties
        (getWmiProperties('Win32_BaseBoard',
qw/SerialNumber Product Manufacturer/)) {
        $baseBoardSerial = $Properties->{SerialNumber};
        $ssn = $Properties->{SerialNumber} unless $ssn;
        $smodel = $Properties->{Product} unless $smodel;
        $smanufacturer = $Properties->{Manufacturer} unless $smanufacturer;

    }




        $inventory->setBios({

                SMODEL => $smodel,
                SMANUFACTURER =>  $smanufacturer,
                SSN => $ssn,
                BDATE => $bdate,
                BVERSION => $bversion,
                BMANUFACTURER => $bmanufacturer,
                MMANUFACTURER => $mmanufacturer,
                MSN => $msn,
                MMODEL => $model,
                ASSETTAG => $assettag,
                ENCLOSURESERIAL => $enclosureSerial,
                BASEBOARDSERIAL => $baseBoardSerial,
                BIOSSERIAL => $biosSerial,

                });

    if ($bmanufacturer eq 'Bochs' || $model eq 'Bochs') {
        $inventory->setHardware ({
           VMSYSTEM => 'QEMU',
        });
    }



}
1;
