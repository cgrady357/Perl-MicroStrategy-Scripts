#!/C:/Perl/bin/perl.exe
# by Craig Grady
# Date Created:  07/21/2008

#use strict;
use warnings;
use DBI;
no warnings 'once';
use aliased 'Business::Intelligence::MicroStrategy::CommandManager' => 'Cmdmgr';

my $date_of_last_run = '06/12/2009';

#globals
my $config_path =
  "C:\\code\\perl\\cfg";
{ package Connstr; require "$config_path\\msi_desktop.cfg"; }

#main
my $db_con = $Connstr::connstr{term};
my $dbh = DBI->connect( @$db_con, { RaiseError => 1, AutoCommit => 1 } )
  or die( $DBI::errstr . " Connect string: " . join( " ", @{$db_con} ) );

my $sth = $dbh->prepare(
q{SELECT disabled_users.id FROM disabled_users WHERE disabled_users.disabled_date < #}
      . $date_of_last_run
      . q{# AND disabled_users.deleted_date is null;} )
  or die( $dbh->errstr );

$sth->execute or die( $dbh->errstr );
my $usr_list = $sth->fetchall_arrayref() or die( $dbh->errstr );
$sth->finish();
$dbh->disconnect();

my $script = "delete.scp";

my $exe = Cmdmgr->new;
my $fh;
open( $fh, ">", $script ) or die( $!, $? );
for my $user (@$usr_list) {
    print $fh $exe->delete_user(
        USER    => $user->[0],
        CASCADE => "TRUE"
      ),
      "\n";
}
$exe->set_connect(
    PROJECTSOURCENAME => $Connstr::connstr{msi1}->[0],
    USERNAME          => $Connstr::connstr{msi1}->[1],
    PASSWORD          => $Connstr::connstr{msi1}->[2]
);
$exe->set_inputfile($script);
my ( $out, $not_ok, $ok ) = ( "delete.log", "delete.nok", "delete.ok" );
$exe->set_resultsfile(
    RESULTSFILE => $out,
    FAILFILE    => $not_ok,
    SUCCESSFILE => $ok
);
$exe->set_showoutput;
$exe->run_script;
