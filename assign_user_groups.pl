#!/C:/Perl/bin/perl.exe
# by Craig Grady
# Date Created:  05/04/2009

#use strict;
use warnings;
no warnings 'once';
use aliased 'Business::Intelligence::MicroStrategy::CommandManager' => 'Cmdmgr';
use aliased 'Business::Intelligence::MicroStrategy::CommandManager::ParseLogs' => 'ParseLogs';

#globals
my $config_path = "C:\\code\\perl\\cfg";
{ package Connstr; require "$config_path\\msi_desktop.cfg"; }

#main
my $script = "user_grp.scp";
my $iserver = "dlsw";

my $exe = Cmdmgr->new;
my $fh;
open( $fh, ">", $script ) or die( $!, $? );
print $fh $exe->list_user_properties(
    PROPERTIES => ["GROUPS"],
    USER       => "wi309034", 
  ),
  "\n";
$exe->set_connect(
    PROJECTSOURCENAME => $Connstr::connstr{$iserver}->[0],
    USERNAME          => $Connstr::connstr{$iserver}->[1],
    PASSWORD          => $Connstr::connstr{$iserver}->[2]
);
$exe->set_inputfile($script);
my ( $out, $not_ok, $ok ) = map { "user_grp." . $_ } ( "log", "nok", "ok" );
$exe->set_resultsfile(
    RESULTSFILE => $out,
    FAILFILE    => $not_ok,
    SUCCESSFILE => $ok
);
$exe->set_showoutput;
$exe->run_script;

my $parse = ParseLogs->new;
my $result = $parse->parse_list_groups(FILE => $out);

$script = "assign.scp";
open( $fh, ">", $script ) or die( $!, $? );
for my $grp(@$result) {  
	print $fh $exe->alter_user(
        	USER           => "eay9963d", 
	        GROUP          => $grp
	    ),
        "\n";
}
( $out, $not_ok, $ok ) = map { "assign." . $_ } ( "log", "nok", "ok" );
$exe->set_resultsfile(
    RESULTSFILE => $out,
    FAILFILE    => $not_ok,
    SUCCESSFILE => $ok
);
$exe->set_connect(
    PROJECTSOURCENAME => $Connstr::connstr{$iserver}->[0],
    USERNAME          => $Connstr::connstr{$iserver}->[1],
    PASSWORD          => $Connstr::connstr{$iserver}->[2]
);
$exe->set_inputfile($script);
$exe->run_script;
