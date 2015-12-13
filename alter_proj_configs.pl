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
my @projects = (
    "ERR - Production",
    "Integrated Sales and Churn (RISE)",
);


my $iserver_source = CommandManager->new;
$iserver_source->set_connect(
    PROJECTSOURCENAME => $Connstr::connstr{npr1}->[0],
    USERNAME          => $Connstr::connstr{npr1}->[1],
    PASSWORD          => $Connstr::connstr{npr1}->[2]
);


my $iserver_target = CommandManager->new;
$iserver_target->set_connect(
    PROJECTSOURCENAME => $Connstr::connstr{msi1}->[0],
    USERNAME          => $Connstr::connstr{msi1}->[1],
    PASSWORD          => $Connstr::connstr{msi1}->[2]
);


sub parse_config {
	my $file = shift;
	my $config = {};
	my $fh;
	open($fh, $file) or die($?, $!);
	while(<$fh>){
    /Description = /   && do { ( undef, $config->{DESCRIPTION} ) = split( /=/, $_ ); };
    /Warehouse name = / && do { ( undef, $config->{WAREHOUSE} ) = split( /=/, $_ ); };
    /Project Status = /  && do { ( undef, $config->{STATUS} ) = split( /=/, $_ ); };
    /Show status = /    && do { ( undef, $config->{SHOWSTATUS} ) = split( /=/, $_ ); };
    /Status On Top = /  && do { ( undef, $config->{STATUSONTOP} ) = split( /=/, $_ ); };
    /HTML Document Directory = /
      && do { ( undef, $config->{DOCDIRECTORY} ) = split( /=/, $_ ); };
    /Maximum number of elements to display = /
      && do { ( undef, $config->{MAXNOATTRELEMS} ) = split( /=/, $_ ); };
    /Use linked Warehouse login for execution = /
      && do { ( undef, $config->{USEWHLOGINEXEC} ) = split( /=/, $_ ); };
    /Enable deleting of object dependencies = /
      && do { ( undef, $config->{ENABLEOBJECTDELETION} ) = split( /=/, $_ ); };
    /Maximum value of report execution time = /
      && do { ( undef, $config->{MAXREPORTEXECTIME} ) = split( /=/, $_ ); };
    /Maximum value of report result rows = /
      && do { ( undef, $config->{MAXNOREPORTRESULTROWS} ) = split( /=/, $_ ); };
    /Maximum value of element rows = /
      && do { ( undef, $config->{MAXNOELEMROWS} ) = split( /=/, $_ ); };
    /Maximum value  of Intermediate result rows = /
      && do { ( undef, $config->{MAXNOINTRESULTROWS} ) = split( /=/, $_ ); };
    /Maximum value of jobs per user account = /
      && do { ( undef, $config->{MAXJOBSUSERACCT} ) = split( /=/, $_ ); };
    /Maximum value of jobs per user session = /
      && do { ( undef, $config->{MAXJOBSUSERSESSION} ) = split( /=/, $_ ); };
    /Maximum value of executing jobs per user = /
      && do { ( undef, $config->{MAXEXECJOBSUSER} ) = split( /=/, $_ ); };
    /Maximum jobs per project = /
      && do { ( undef, $config->{MAXJOBSPROJECT} ) = split( /=/, $_ ); };
    /MaxUserSessionsProject = /
      && do { ( undef, $config->{MAXUSERSESSIONSPROJECT} ) = split( /=/, $_ ); };
      #  /Default Project Drill Map = /
      #&& do { ( undef, $config->{PROJDRILLMAP} ) = split( /=/, $_ ); };
    /Report Template = / && do { ( undef, $config->{REPORTTPL} ) = split( /=/, $_ ); };
    /Report Show Empty Template = /
      && do { ( undef, $config->{REPORTSHOWEMPTYTPL} ) = split( /=/, $_ ); };
    /Template Template = /
      && do { ( undef, $config->{TEMPLATETPL} ) = split( /=/, $_ ); };
    /Template Show Empty Template = /
      && do { ( undef, $config->{TEMPLATESHOWEMPTYTPL} ) = split( /=/, $_ ); };
    /Metric Template = / && do { ( undef, $config->{METRICTPL} ) = split( /=/, $_ ); };
    /Metric Show Empty Template = /
      && do { ( undef, $config->{METRICSHOWEMPTYTPL} ) = split( /=/, $_ ); };
    /Name = / && do { ( undef, $config->{PROJECT} ) = split( /=/, $_ ); };
    }
    return $config;
}


my ($fh, $c, @pconfigs);
$c = 0;
my $script = "z.scp";
my ($out, $not_ok, $ok) = ("z.log","z.nok", "z.ok");

for my $proj (@projects) {
	open($fh, ">", $script) or die($!, $?);
	print $fh $iserver_source->list_project_config_properties($proj), "\n";
	$iserver_source->set_inputfile($script);
	$iserver_source->set_resultsfile(
    		RESULTSFILE => $out,
    		FAILFILE    => $not_ok,
    		SUCCESSFILE => $ok
	);
	$iserver_source->run_script;
	push @pconfigs, [$proj, parse_config($out)];
	(my $newfile = $proj) =~ s/\s+//g; 
	move($out,"pc_$newfile.log") or die "Move failed: $!";
	-z $not_ok ? ( unlink $not_ok or die ($?, $!) ): (move($not_ok,"pc_$newfile.nok") or die "Move failed: $!");
	unlink $ok or die ($?, $!);
	close $fh;
}

unlink $script or die($?, $!);
my $q = '"';
$c= 0;
for my $p (@pconfigs) {
	my ($proj, $info) = @$p;
	my $fh;
	open($fh, ">>", $script) or die($!, $?);
	my @items;
	for(keys %$info) { 
		$info->{$_} =~ s/^\s+//g; 
		$info->{$_} =~ s/\s+$//g; 
		$info->{$_} = undef unless $info->{$_} =~ /\w/;
		if(defined($info->{$_})) { push @items, $_, $info->{$_}; }
	}
	print $fh $iserver_target->alter_project_config(@items), "\n";
	$iserver_target->set_inputfile($script);
	$iserver_target->set_resultsfile(
    		RESULTSFILE => $out,
    		FAILFILE    => $not_ok,
    		SUCCESSFILE => $ok
	);
	$iserver_target->run_script;
	(my $newfile = $proj) =~ s/\s+//g; 
	move($out,"alter_$newfile.log") or die "Move failed: $!";
	-z $not_ok ? ( unlink $not_ok or die ($?, $!) ): (move($not_ok,"alter_$newfile.nok") or die "Move failed: $!");
	unlink $ok or die ($?, $!);
}