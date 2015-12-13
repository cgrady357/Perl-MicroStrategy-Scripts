#!/C:/Perl/bin/perl.exe
# by Craig Grady
# Date Created:  02/02/2009

#use strict;
use warnings;
use DBI;
no warnings 'once';
use aliased 'Business::Intelligence::MicroStrategy::CommandManager' => 'Cmdmgr';
use Spreadsheet::Excel::Utilities qw(xls2aref);

#globals
my $config_path =
  "C:\\Documents and Settings\\cgrady04\\My Documents\\Code\\perl\\cfg";
{ package Connstr; require "$config_path\\msi_desktop.cfg"; }

my $script = "ldaplink.scp";
my $iserver = "dlsw";

#get user info
my $file   = "ldap_lab_users.xls";
$page = 0;
my $usr_list = xls2aref( $file, $page );

my $exe = Cmdmgr->new;
my $fh;
open( $fh, ">", $script ) or die( $!, $? );
for my $user (@$usr_list) {
    (my $old_name = $user->[0]) =~ s/lab$//i;
    $user->[1] =~ s/["]//g;
    print $fh $exe->alter_user(
        USER   	       => $old_name,
	NAME	       => $user->[0],
        LDAPLINK       => $user->[1],
      ),
      "\n";
}
$exe->set_connect(
    PROJECTSOURCENAME => $Connstr::connstr{$iserver}->[0],
    USERNAME          => $Connstr::connstr{$iserver}->[1],
    PASSWORD          => $Connstr::connstr{$iserver}->[2]
);
$exe->set_inputfile($script);
my ( $out, $not_ok, $ok ) = ( "ldaplink.log", "ldaplink.nok", "ldaplink.ok" );
$exe->set_resultsfile(
    RESULTSFILE => $out,
    FAILFILE    => $not_ok,
    SUCCESSFILE => $ok
);
$exe->set_showoutput;
$exe->run_script;
