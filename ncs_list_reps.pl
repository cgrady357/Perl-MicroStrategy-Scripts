#!/C:/Perl/bin/perl.exe
# by Craig Grady
# created:  10/24/2007

use strict;
use warnings;
use DBI;
use Spreadsheet::WriteExcel;
#'Connstr::connstr', 'Connstr::login'; these variables used only once, this is ok
#no warnings 'once';

#globals
my %sql = ( 
services => q{select distinct a11.MR_OBJECT_ID,a11.MR_OBJECT_NAME,a13.MR_USER_ID,a14.MR_USER_NAME
from 
NCS75.MSTROBJNAMES a11, 
NCS75.MSTROBJDEPN a12, 
NCS75.MSTRSUBSCRIPTIONS a13, 
NCS75.MSTRUSERS a14
where a11.MR_OBJECT_TYPE = 19 and
      a11.MR_OBJECT_ID = a12.MR_INDEP_OBJID and 
      a12.MR_DEPN_OBJID = a13.MR_SUB_SET_ID and 
      a13.MR_USER_ID = a14.MR_USER_ID},

subs => q{ SELECT A2.MR_SUB_SET_ID, A5.MR_OBJECT_NAME, A2.MR_SUB_GUID, A3.MR_USER_NAME, A4.MR_ADDRESS_NAME, A4.MR_PHYSICAL_ADD, A1.MR_PROP_VALUE 
FROM NCS75.MSTREXTENDEDPROPS A1, 
     NCS75.MSTRSUBSCRIPTIONS A2, 
     NCS75.MSTRUSERS A3, 
     NCS75.MSTRADDRESSES A4, 
     NCS75.MSTROBJNAMES A5
WHERE 
A1.MR_OBJECT_ID= A2.MR_SUB_GUID AND 
A3.MR_USER_ID=A2.MR_USER_ID AND 
A4.MR_ADDRESS_ID=A2.MR_ADDRESS_ID AND 
A5.MR_OBJECT_ID=A2.MR_SUB_SET_ID AND
A1.MR_PROP_ID = 'objectId' AND
A2.MR_SUB_SET_ID IN (SELECT MR_DEPN_OBJID FROM NCS75.MSTROBJDEPN WHERE MR_INDEP_OBJID=? AND MR_DEPNOBJ_TYPE=17) },

rpts => q{ SELECT OBJECT_ID, OBJECT_NAME FROM DSSMDOBJINFO WHERE OBJECT_ID=?},
);

my $config_path = "C:\\Code\\perl\\cfg";
{ package Connstr; require "$config_path\\warehouse.cfg"; }

my $dbh = DBI->connect(@{$Connstr::connstr{NCS75}}) or die($DBI::errstr); 
	
my $sth = $dbh->prepare($sql{services}) or die($dbh->errstr);
$sth->execute or die($dbh->errstr);
my $users = $sth->fetchall_arrayref();

my %ncs;
my @services;
my @order;

for my $svc(@$users) { $ncs{$$svc[0]} = $$svc[1]; }

$sth = $dbh->prepare($sql{subs}) or die($dbh->errstr);

for my $key (keys %ncs) {
	$sth->execute($key) or die($dbh->errstr);
	my $result = $sth->fetchall_arrayref();
	push @services, @$result;
	for(@$result) { push @order, $key; }
}

$sth->finish();
$dbh->disconnect();

#the NCS entries are for multiple schemas, get them for Olap75 schema first

$dbh = DBI->connect(@{$Connstr::connstr{OLAP75}}) or die($DBI::errstr);
$sth = $dbh->prepare($sql{rpts}) or die($dbh->errstr);

my ($mday,$mon,$year) = (localtime(time))[3,4,5];
my $postfix = sprintf("%d%02d%02d",$year += 1900 ,++$mon, $mday); #ie, 20060823
my $workbook   = Spreadsheet::WriteExcel->new("ncs_" . $postfix . ".xls");
my $worksheet1 = $workbook->add_worksheet("cluster");
my $format     = $workbook->add_format(color => 'black', bold => 1);
$format->set_underline();
my $labels = [ qw(NCS_Service_Name Subscription_Set_ID Subscription_Set_Name A2.MR_SUB_GUID A3.MR_USER_NAME A4.MR_ADDRESS_NAME A4.MR_PHYSICAL_ADD A1.MR_PROP_VALUE Report_Name)];
$worksheet1->write('A1', $labels, $format);


my $c;
my @output;
for my $srv(@services) {
	my $item = $$srv[6];
	$sth->execute($item) or die($dbh->errstr);
	my $result = $sth->fetchall_arrayref();
	my $i = $ncs{$order[$c++]};
	for(@$result) { push @output, [ $i, @$srv, ${$_}[1] ]; }
}

$worksheet1->write_col('A2', \@output);

$sth->finish();
$dbh->disconnect();

#get them for Stand75 schema next

$dbh = DBI->connect(@{$Connstr::connstr{STAND75}}) or die($DBI::errstr);
$sth = $dbh->prepare($sql{rpts}) or die($dbh->errstr);

my $worksheet2 = $workbook->add_worksheet("plsw1300");
$worksheet2->write('A1', $labels, $format);


$c = 0;
@output = ();
for my $srv(@services) {
	my $item = $$srv[6];
	$sth->execute($item) or die($dbh->errstr);
	my $result = $sth->fetchall_arrayref();
	my $i = $ncs{$order[$c++]};
	for(@$result) { push @output, [ $i, @$srv, ${$_}[1] ]; }
}

$worksheet2->write_col('A2', \@output);

$sth->finish();
$dbh->disconnect();

#get them for Alone75 schema next

$dbh = DBI->connect(@{$Connstr::connstr{ALONE75}}) or die($DBI::errstr);
$sth = $dbh->prepare($sql{rpts}) or die($dbh->errstr);

my $worksheet3 = $workbook->add_worksheet("plsw1286");
$worksheet3->write('A1', $labels, $format);


$c = 0;
@output = ();
for my $srv(@services) {
	my $item = $$srv[6];
	$sth->execute($item) or die($dbh->errstr);
	my $result = $sth->fetchall_arrayref();
	my $i = $ncs{$order[$c++]};
	for(@$result) { push @output, [ $i, @$srv, ${$_}[1] ]; }
}

$worksheet3->write_col('A2', \@output);

$sth->finish();
$dbh->disconnect();
