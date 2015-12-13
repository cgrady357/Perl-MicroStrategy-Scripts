#!/C:/Perl/bin/perl.exe

use DBI;
use strict;
use warnings;
use lib "C:\\code\\perl";


my $config_path = "C:\\code\\perl\\cfg";
{ package Connstr; require "$config_path\\warehouse.cfg"; }

my %sql = (
ids => qq { select object_id, object_name from dssmdobjinfo where object_type=44 },   
item => qq { select object_name from dssmdobjinfo where object_id in
(select object_id from dssmdlnkitem where linkitem_id in 
(select linkitem_id from dssmdlnkitem where object_id=?) and object_type=34)}, );

#main
my $dbh = DBI->connect(@{$Connstr::connstr{ISERVER2}}, { RaiseError => 1, AutoCommit => 1 }) or die ($DBI::errstr . " Connect string: " . join(" ", @{$Connstr::connstr{ISERVER2}}));;

my $sth = $dbh->prepare($sql{ids});
$sth->execute;
my $roles = $sth->fetchall_arrayref();
my @not_used;
$sth = $dbh->prepare($sql{item}); 
for my $r(@$roles) { 
	$sth->execute($$r[0]); 
	my $user = $sth->fetchall_arrayref;
	my $cnt;	
	for my $u (@$user) { print $$r[1], " ::: ", @$u, "\n"; $cnt = 1;}
	if(!$cnt) { push @not_used, $$r[1]; }
}

print "\nNOT USED: \n";
for(@not_used) { print $_, "\n"; }
