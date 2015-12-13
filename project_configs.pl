#!/C:/Perl/bin/perl.exe
# by Craig Grady
# Date Created:  10/04/2008

use strict;
use warnings;
use DBI;
no warnings 'once';
use aliased 'Business::Intelligence::MicroStrategy::CommandManager';
use File::Copy;

#globals
my $config_path = "C:\\code\\perl\\cfg";
{ package Connstr; require "$config_path\\msi_desktop.cfg"; }

#main
my @projects = ("Retail Scorecard",
		);


my $exe = CommandManager->new;
my $fh;
$exe->set_connect(@{$Connstr::connstr{tpp2}});
$exe->set_showoutput;

for(@projects) {
	my $script = "c.scp";
	open($fh, ">", $script) or die($!, $?);
	print $fh $exe->list_project_config_properties($_), "\n";
	$exe->set_inputfile($script);
	$exe->set_resultsfile("$c.log","$c.nok", "$c.ok");
	$exe->run_script;
	(my $newfile = $_) =~ s/\s+//g;
	move("c.log","$newfile.log") or die "Move failed: $!";
	-z "c.nok" ? ( unlink "c.nok" or die ($?, $!) ): (move("c.nok","$newfile.nok") or die "Move failed: $!");
	unlink "c.ok" or die ($?, $!);
}
