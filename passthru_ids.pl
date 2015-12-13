#!/C:/Perl/bin/perl.exe
# by Craig Grady
# created 11/18/2008
# use after project migration, to copy Warehouse Pass-through passwords from source metadata to target metadata

use strict;
use warnings;
use DBI;

my $config_path =
  "C:\\Code\\perl\\cfg";
{ package Connstr; require "$config_path\\warehouse.cfg"; }
my ( $source, $target );

$source = $Connstr::connstr{ALONE75};
$target = $Connstr::connstr{OLAP75};

my %sql = (
    ids   => qq{ select LOGIN, PASSWD from DSSMDUSRACCT },
    login => qq{UPDADTE DSSMDUSRACCT SET PASSWD=? where LOGIN=? },
);

#main
my $dbh = DBI->connect( @{$source}, { RaiseError => 1, AutoCommit => 1 } )
  or die( $DBI::errstr . " Connect string: " . join( " ", @{$source} ) );

my $dbh2 = DBI->connect( @{$target}, { RaiseError => 1, AutoCommit => 1 } )
  or die( $DBI::errstr . " Connect string: " . join( " ", @{$target} ) );

my $sth = $dbh->prepare( $sql{ids} );
$sth->execute;
my $aref = $sth->fetchall_arrayref();

$sth2 = $dbh2->prepare( $sql{login} );
for (@$aref) { $sth2->execute( $_->[1], $_->[0] ); }