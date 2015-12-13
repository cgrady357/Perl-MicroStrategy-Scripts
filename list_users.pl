#!/C:/Perl/bin/perl.exe
# by Craig Grady
# Date Created:  08/19/2008
# modified:  12/18/2008

#use strict;
use warnings;
use DBI;
no warnings 'once';
use aliased 'Business::Intelligence::MicroStrategy::CommandManager';
use Regexp::Common;
use File::Copy;

#globals
my $config_path = "C:\\code\\perl\\cfg";
{ package Connstr; require "$config_path\\msi_desktop.cfg"; }

#main
my $scp = "grp.scp";
my $msi = CommandManager->new;
my $proj_src = "msi1";
$msi->set_connect(
    PROJECTSOURCENAME => $Connstr::connstr{$proj_src}->[0],
    USERNAME          => $Connstr::connstr{$proj_src}->[1],
    PASSWORD          => $Connstr::connstr{$proj_src}->[2]
);

$msi->set_inputfile($scp);
my ($out, $not_ok, $ok) = ("grp.log","grp.nok", "grp.ok");
$msi->set_resultsfile(
    RESULTSFILE => $out,
    FAILFILE    => $not_ok,
    SUCCESSFILE => $ok
);

my $fh;
open($fh, ">", $scp) or die($!, $?);
print $fh $msi->list_user_groups;
close $fh;
$msi->run_script;

my (@grps, %grps);
open($fh, $out) or die ($!, $?);
while(my $line = <$fh>) { 
	next unless $line =~ /Group/; 
	chomp $line; 
	(undef, my $grp) = split("= ", $line); 
	push @grps, $grp; 
	my $log = $grp;
	$log =~ s/\s+/_/g;
	$log =~ s/\//_/g;
	$log .= ".log";
	$grps{$grp} = $log;  
}
close $fh;

my $cnt = 0;
for my $grp (@grps) {
	$scp = $cnt . ".scp";
	$out = $cnt . ".log";
	$not_ok = $cnt . "nok.log";
	$ok = $cnt . "ok.log";
	open($fh, ">", $scp) or die ($scp, $!, $?);
	print $fh $msi->list_user_group_members($grp), "\n";
	close $fh;
	$msi->set_inputfile($scp);
	$msi->set_resultsfile(
		RESULTSFILE => $out,
		FAILFILE    => $not_ok,
		SUCCESSFILE => $ok
	);	
	$msi->run_script;
	$cnt++;
	unlink $scp;
	my $file = $grp . ".log";
	$file =~ s/\s+/_/g;
	$file =~ s/\//_/g;
	move($out, $file) or die($?, $!);
	unlink $not_ok, $ok;
}


my %names;
my %groups;
for my $file(keys %grps) {
	open($fh, $grps{$file}) or die("No such file: ", $grps{$file}, $?, $!);
	while (my $line = <$fh>) {
	        next unless $line =~ /Members/;	
		chomp $line;
		(undef, my $list) = split("=", $line);
		while($list =~ /$RE{balanced}{-parens=>'()[]'}{-keep}/g) { 
			my $id = $`;
			my $usr = $&; 
			$list = $'; 
			$id =~ s/,//;
			$id =~ s/^\s+//; 
			$id =~ s/\s+$//;
			$usr =~ s/[()]//g;
			$names{$id} = $usr;
			$groups{$file}{$id}++;
		}
	}
	close $fh;
}

my $q = '"';
open($fh, ">", "grp.txt") or die($?, $!);
print $fh "USER GROUP", "\t", "USER ID", "\t", "USER NAME", "\n";
for my $group (sort keys %groups) {
	for my $name ( sort keys %{ $groups{$group} } ) {
		print $fh $group, "\t", uc($name),"\t", uc($names{$name}), "\n"; 
	}
}	