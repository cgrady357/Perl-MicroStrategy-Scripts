#!/C:/Perl/bin/perl.exe
# by Craig Grady
# Date Created:  10/17/2008

#use strict;
use warnings;
no warnings 'once';
use aliased 'Business::Intelligence::MicroStrategy::CommandManager';
use Spreadsheet::Excel::Utilities qw(xls2aref);

#globals
my $config_path =
  "C:\\code\\perl\\cfg";
{ package Connstr; require "$config_path\\msi_desktop.cfg"; }

my $server = "npr1";
my $file   = "delete_users.xls";
$page = 0;
my $usr_list = xls2aref( $file, $page );

my $script = "del1300.scp";

my $exe = CommandManager->new;
my $fh;
open( $fh, ">", $script ) or die( $!, $? );
for my $user (@$usr_list) {
    print $fh $exe->delete_user( USER => $user->[0], CASCADE => "TRUE", ), "\n";
}

my ( $out, $not_ok, $ok ) = ( "del1300.log", "del1300.nok", "del1300.ok" );

$exe->set_connect(
    PROJECTSOURCENAME => $Connstr::connstr{$server}->[0],
    USERNAME          => $Connstr::connstr{$server}->[1],
    PASSWORD          => $Connstr::connstr{$server}->[2]
);

$exe->set_inputfile($script);
$exe->set_resultsfile(
    RESULTSFILE => $out,
    FAILFILE    => $not_ok,
    SUCCESSFILE => $ok
);
$exe->set_showoutput;
$exe->run_script;