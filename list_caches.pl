#!/C:/Perl/bin/perl.exe
# by Craig Grady
# Date Created:  03/09/2009

#use strict;
use warnings;
no warnings 'once';
use aliased 'Business::Intelligence::MicroStrategy::CommandManager' => 'Cmdmgr';
use aliased 'Business::Intelligence::MicroStrategy::CommandManager::ParseLogs' => 'ParseLogs';
use Text::Balanced qw(extract_bracketed extract_multiple);

#globals
my $config_path =
  "C:\\code\\perl\\cfg";
{ package Connstr; require "$config_path\\msi_desktop.cfg"; }

my $iserver = "tpp2";
my $exe     = Cmdmgr->new;
my $fh;
my $proj_src = "PLSW1286";

#main

$exe->set_connect(
    PROJECTSOURCENAME => $Connstr::connstr{$iserver}->[0],
    USERNAME          => $Connstr::connstr{$iserver}->[1],
    PASSWORD          => $Connstr::connstr{$iserver}->[2]
);

my ( $script, $out, $not_ok, $ok ) = map { $proj_src . $_ } ( ".scp", ".log", ".nok", ".ok" );
$exe->set_inputfile($script);
open($fh, '>' , $script) or die($!, $?);
print $fh $exe->list_projects( "ALL" ), "\n";
$exe->run_script;

my $parse = ParseLogs->new;
$parse->parse_list_projects(FILE => $out);

$file = 1;
for my $proj($parse->list_projects) { 
	( $script, $out, $not_ok, $ok ) = map { $proj . $_ } ( ".scp", ".log", ".nok", ".ok" );
	open($fh, '>' , $script) or die($!, $?);
	print $fh $exe->list_report_caches($proj), "\n";
	$exe->run_script;
	$file++;
}
