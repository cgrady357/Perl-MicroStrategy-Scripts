#!/C:/Perl/bin/perl.exe

use DBI;
use strict;
use warnings;
use lib "C:\\code\\perl";
use Shared::Sql;

my $config_path = "C:\\code\\perl\\cfg";
{ package Connstr; require "$config_path\\warehouse.cfg"; }

my %sql = (
ids => qq { select PROJECT_ID, OBJECT_ID from 	DSSMDOBJINFO where OBJECT_ID = '4FC8D2504C3CFAC89E454DB9908E2CAA' },
item => qq { DELETE FROM DSSMDLNKITEM  WHERE PROJECT_ID=? AND OBJECT_ID =? },
acct => qq { DELETE FROM DSSMDUSRACCT  WHERE PROJECT_ID=? AND OBJECT_ID =? },
secu => qq { DELETE FROM DSSMDOBJSECU  WHERE PROJECT_ID=? AND OBJECT_ID =? },
prop => qq { DELETE FROM DSSMDOBJPROP  WHERE PROJECT_ID=? AND OBJECT_ID =? },
info => qq { DELETE FROM DSSMDOBJINFO  WHERE PROJECT_ID=? AND OBJECT_ID =? },
depn => qq { DELETE FROM DSSMDOBJDEPN  WHERE PROJECT_ID=? AND OBJECT_ID =? },
defn => qq { DELETE FROM DSSMDOBJDEFN  WHERE PROJECT_ID=? AND OBJECT_ID =? }, );

#main
my $dbh = DBI->connect(@{$Connstr::connstr{OLAP75}}, { RaiseError => 1, AutoCommit => 1 }) or die ($DBI::errstr . " Connect string: " . join(" ", @{$Connstr::connstr{OLAP75}}));;

my $sth = $dbh->prepare($sql{ids});
$sth->execute;
my $aref = $sth->fetchall_arrayref();

$sth = $dbh->prepare($sql{item}); 
for(@$aref) { $sth->execute(@$_); }

$sth = $dbh->prepare($sql{acct}); 
for(@$aref) { $sth->execute(@$_); }

$sth = $dbh->prepare($sql{secu}); 
for(@$aref) { $sth->execute(@$_); }

$sth = $dbh->prepare($sql{prop});
for(@$aref) { $sth->execute(@$_) ; }

$sth = $dbh->prepare($sql{info}) ;
for(@$aref) { $sth->execute(@$_) ; }

$sth = $dbh->prepare($sql{depn});
for(@$aref) { $sth->execute(@$_) ; }

$sth = $dbh->prepare($sql{defn});
for(@$aref) { $sth->execute(@$_) ; }
