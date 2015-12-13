use strict;
use warnings;

my $Registry;
use Win32::TieRegistry 0.20 (
    TiedRef     => \$Registry,
    Delimiter   => "/",
    ArrayValues => 1,
    SplitMultis => 1,
    AllowLoad   => 1,
    qw( REG_SZ REG_EXPAND_SZ REG_DWORD REG_BINARY REG_MULTI_SZ
      KEY_READ KEY_WRITE KEY_ALL_ACCESS ),
);
$Registry->Delimiter("/");
my $hostname   = Win32::NodeName();

my %reg_types = (
    0  => "REG_NONE",
    1  => "REG_SZ",
    2  => "REG_EXPAND_SZ",
    3  => "REG_BINARY",
    4  => "REG_DWORD",
    5  => "REG_DWORD_BIG_ENDIAN",
    6  => "REG_LINK",
    7  => "REG_MULTI_SZ",
    8  => "REG_RESOURCE_LIST",
    9  => "REG_FULL_RESOURCE_DESCRIPTOR",
    10 => "REG_RESOURCE_REQUIREMENTS_LIST",
    11 => "REG_QWORD",
);

#This where you will find system DSN's
#HKEY_LOCAL_MACHINE/Software/Odbc/Odbc.ini/Odbc Data sources
my $lm = $Registry->{"LMachine/Software/Odbc/Odbc.ini/"}
  or die "Can't read LMachine/Software/Odbc/Odbc.ini/ key: $^E\n";
my @lm_subkeys = $lm->SubKeyNames;
for my $sk (@lm_subkeys) {
    my @vn = $lm->{$sk}->ValueNames;
    for my $vname (@vn) {
        my ( $value_data, $value_type ) = $lm->{$sk}->GetValue($vname);
        print $hostname, "\t", $sk, "\t", $vname, "\t", $reg_types{$value_type}, "\t",
          $value_data, "\n";
    }
}

#This is where you will find user DSN's
#HKEY_CURRENT_USER/Software/Odbc/Odbc.ini/Odbc Data sources
my $cu = $Registry->{"CUser/Software/Odbc/Odbc.ini/"}
  or die "Can't read CUser/Software/Odbc/Odbc.ini/ key: $^E\n";
my @cu_subkeys = $cu->SubKeyNames;
for my $sk (@cu_subkeys) {
    my @vn = $cu->{$sk}->ValueNames;
    for my $vname (@vn) {
        my ( $value_data, $value_type ) = $cu->{$sk}->GetValue($vname);
        print $hostname, "\t", $sk, "\t", $vname, "\t", $reg_types{$value_type}, "\t",
          $value_data, "\n";
    }
}

