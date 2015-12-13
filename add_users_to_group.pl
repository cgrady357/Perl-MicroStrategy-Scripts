#!/C:/Perl/bin/perl.exe
# by Craig Grady
# Date Created:  07/21/2008

#use strict;
use warnings;
no warnings 'once';
use aliased 'Business::Intelligence::MicroStrategy::CommandManager' => 'Cmdmgr';
use Spreadsheet::Excel::Utilities qw(xls2aref);

#globals
my $config_path =
  "C:\\Documents and Settings\\cgrady04\\My Documents\\Code\\perl\\cfg";
{ package Connstr; require "$config_path\\msi_desktop.cfg"; }

#main

my $script = "add2grp.scp";
my $iserver = "npr1";

#get user info
my $file   = "CDB_NEW_USER_PSWD.xls";
$page = 2;
my $usr_list = xls2aref( $file, $page );

my $exe = Cmdmgr->new;
my $fh;
my $user_group = "Web Integrated Sales and Churn";
open( $fh, ">", $script ) or die( $!, $? );
for my $user (@$usr_list) {
    (my $name = $user->[1]) =~ s/["]//g;
    print $fh $exe->create_user(
        USER           => $user->[0],
        FULLNAME       => $name,
        PASSWORD       => $user->[2],
        WHLINK         => $user->[0],
        WHPASSWORD     => $user->[2],
        ALLOWCHANGEPWD => "TRUE",
        CHANGEPWD      => "FALSE",
        ENABLED        => "ENABLED",
        GROUP          => $user_group,
    ), 
    "\n";
}
$exe->set_connect(
    PROJECTSOURCENAME => $Connstr::connstr{$iserver}->[0],
    USERNAME          => $Connstr::connstr{$iserver}->[1],
    PASSWORD          => $Connstr::connstr{$iserver}->[2]
);
$exe->set_inputfile($script);
my ( $out, $not_ok, $ok ) = map { "add2grp" . $_; } ( ".log", ".nok", ".ok" );
$exe->set_resultsfile(
    RESULTSFILE => $out,
    FAILFILE    => $not_ok,
    SUCCESSFILE => $ok
);
$exe->set_showoutput;
$exe->run_script;

