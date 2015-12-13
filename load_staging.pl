#!/C:/Perl/bin/perl.exe

use strict;
use DBI();
use Getopt::Std;
#add db connection, server, and product vars
my $config_path = "C:\\code\\perl\\cfg";
-e $config_path or die("Config path incorrect $config_path");
{ package Connstr; do "$config_path\\mysql.cfg"; }
{ package Cfg; do "$config_path\\license_audit.cfg"; }
my @servers = @Cfg::servers;
my @product = @Cfg::product;
if ( $#ARGV < 2 ) { die "usage:$0 -y <year> -m <month> -d <day>\n"; } 
my %opts;
getopt('ymd', \%opts); #year, month, day


my $rpt_date=$opts{y} . $opts{m} . $opts{d};
my @license_files = map { $_ . "_" . $rpt_date . "_audit_report.csv" } @servers;

my $dbh = DBI->connect(@{$Connstr::connstr{license}}) or die ($DBI::errstr . " Connect string: " . join(" ", @{$Connstr::connstr{license}}));

my $sth = $dbh->prepare(q{
  INSERT INTO staging (server, product, name, audit_dt) VALUES (?, ?, ?, ?)
}) or die $dbh->errstr;

#format report date to fit mysql std for dates
$rpt_date=$opts{y} . "-" . $opts{m} . "-" . $opts{d};
my $pat = join("|", @product); 
$pat = qr/$pat/;
for(@license_files) {
    open(FILE, "<$_") or die("Can't open file $_", $?, $!);
    my $flag = 0;
    my $server = undef;
    while(my $line = <FILE>) {
          if($line =~ /Product,Enabled Users/) { $flag = 1; }
	  if($line =~ /Project Source, (.*)/) { $server = $1; }
	  if($line =~ /Disabled Users/) { $flag = 0;  }
	  next unless $flag;
	  next unless $line =~ /($pat)/;
	  chomp $line;
	  my ($product, $name) = ($line =~ /^($pat),(.*)/);
          $sth->execute($server, $product, $name, $rpt_date) or die $dbh->errstr;
    }
}

$sth->finish();
$dbh->disconnect();