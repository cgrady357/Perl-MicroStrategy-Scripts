#!/C:/Perl/bin/perl.exe
# by Craig Grady
# Date Created:  02/12/2009

use strict;
use warnings;
no warnings 'once';
use aliased 'Business::Intelligence::MicroStrategy::CommandManager';
use Spreadsheet::Excel::Utilities qw(xls2aref);

#globals
my $config_path =
  "C:\\code\\perl\\cfg";
{ package Connstr; require "$config_path\\msi_desktop.cfg"; }

#main
my $file_path = "C:\\pps\\MSI\\";
my $file   = $file_path . "expire_password_list.xls";
my $page = 0;
my $usr_list = xls2aref( $file, $page );

my $script = "expirepw.scp";
my $iserver = "msi1";

my $exe = CommandManager->new;
my $fh;
open( $fh, ">", $script ) or die( $!, $? );
for my $user (@$usr_list) {
        print $fh $exe->alter_user( 
	    USER      => $user->[1], 
	    ALLOWCHANGEPWD => "TRUE",  
    ),
      "\n";
	print $fh $exe->alter_user( 
	    USER      => $user->[1], 
	    PASSWORD  => $user->[2], 
	    CHANGEPWD => "TRUE", 
            ALLOWSTDAUTH   => "TRUE",  
    ),
      "\n";
}

my ( $out, $not_ok, $ok ) = ( "expirepw.log", "expirepw.nok", "expirepw.ok" );

$exe->set_connect(
    PROJECTSOURCENAME => $Connstr::connstr{$iserver}->[0],
    USERNAME          => $Connstr::connstr{$iserver}->[1],
    PASSWORD          => $Connstr::connstr{$iserver}->[2]
);

$exe->set_inputfile($script);
$exe->set_resultsfile(
    RESULTSFILE => $out,
    FAILFILE    => $not_ok,
    SUCCESSFILE => $ok
);
$exe->set_showoutput;
$exe->run_script;
