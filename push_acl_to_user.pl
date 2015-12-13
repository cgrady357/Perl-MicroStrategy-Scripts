#!/D:/Perl/bin/perl.exe

use strict;
use warnings;
use Config::IniFiles;
use Cwd;
use Business::Intelligence::MicroStrategy::CommandManager;
use Log::Log4perl;
use Program::Exit;
use DBI;
use Getopt::Std;

# push ACL that grants the InsightAdministrator id full control to every login id
# control m job name | server it runs on

#set script variables
our %opts;
getopt( 'fj', \%opts );

my $run_from_desktop = 1;
my $pe               = Program::Exit->new();
$pe->enable_logging(1);

my $script = {};
$script->{job}         = $opts{j};
$script->{server}      = uc( Win32::NodeName() );
$script->{script_name} = $0;
$script->{cwd}         = getcwd();
$script->{cfg_file}    = $opts{f}
  || "D:\\Prod_D\\0AP\\Application\\MicroStrategy\\0AP.ini";

-R $script->{cfg_file}
  or $pe->abnormal_exit(
    FILE_ERROR => "Can't read config file: " . $script->{cfg_file} );
my $cfg = Config::IniFiles->new( -file => $script->{cfg_file} );

if ( !$cfg ) {
    $pe->abnormal_exit(
        OBJECT_ERROR => "Can't create Config::IniFiles object" );
}

for (qw(perl_log perl_log_config new_log_location)) {
    $run_from_desktop
      ? ( $script->{$_} =
          get_config_info( $script->{job}, $_ =~ /log/ ? "desk_" . $_ : $_ ) )
      : ( $script->{$_} = get_config_info( $script->{job}, $_ ) );
}

if ($script->{server} !~ /(D|P|T)LSW/) { $script->{server} = get_config_info( $script->{job}, "iserver" ); }
for (qw(cmdmgr_dir cmdmgr_exe)) {
    $run_from_desktop
      ? ( $script->{$_} = get_config_info( $script->{server}, "desk_" . $_ ) )
      : ( $script->{$_} = get_config_info( $script->{server}, $_ ) );
}

$script->{all_logs} = [];

#configure logging
Log::Log4perl->init( $script->{perl_log_config} );
my $log      = Log::Log4perl->get_logger();
my $appender = Log::Log4perl->appender_by_name("Logfile");
$pe->set_logger( $script->{perl_log_config} );

#functions
sub get_config_info {
    my ( $key, $value ) = @_;
    return $cfg->val( $key, $value );
}

sub get_db_info {
    my $dsn = get_config_info( $script->{job}, "odbc" );
    unless ( $dsn =~ /^dbi:/ ) {
        $dsn = join( '', 'dbi:ODBC:', $dsn );
    }
    my $id  = get_config_info( $script->{server}, "db_id" );
    my $pwd = get_config_info( $script->{server}, "db_pwd" );
    return $dsn, $id, $pwd;
}

sub set_command_manager_variables {
    my $self = shift;
    for my $var ( "scp", "out", "nok", "ok" ) {
        my $name = "cmdmgr_" . $var;
        $self->{$name} = $self->{cmdmgr_dir} . "\\" . $self->{job} . "." . $var;
        unlink $self->{$name};
        push @{ $script->{all_logs} }, $self->{$name};
    }
}

sub get_log_file_name { return $script->{perl_log}; }

# main
$log->info( "Script ", $0, " begin processing" );
my $msi = Business::Intelligence::MicroStrategy::CommandManager->new;
eval { $msi->set_cmdmgr_exe( $script->{cmdmgr_exe} ) };
$pe->abnormal_exit( CMDMGR_ERROR => $@ ) if $@;

my $sql = q{ 
  SELECT DISTINCT info.OBJECT_UNAME user_name, info.ABBREVIATION user_id
  FROM DSSMDOBJINFO info, DSSMDUSRACCT acct
  WHERE info.PROJECT_ID='38A062302D4411D28E71006008960167' 
  AND info.OBJECT_TYPE=34 
  and info.SUBTYPE=8704
  and acct.LOGIN = upper(info.ABBREVIATION)
  and acct.LOGIN <> 'ADMINISTRATOR'
  --AND info.CREATE_TIME > (trunc(sysdate) - 2)
  };

my ( $dbh, $sth );
eval { $dbh = DBI->connect( get_db_info() ) };
$pe->abnormal_exit( DBI_CONNECTION_ERROR => $@ ) if $@;

eval { $sth = $dbh->prepare($sql) };
$pe->abnormal_exit( DBI_PREPARE_ERROR => $@ ) if $@;

eval { $sth->execute };
$pe->abnormal_exit( DBI_EXECUTE_ERROR => $@ ) if $@;
my $result = $sth->fetchall_arrayref();
$sth->finish();
$dbh->disconnect();

eval {
    $msi->set_connect(
        PROJECTSOURCENAME => get_config_info( $script->{job},    "projectsourcename" ),
        USERNAME          => get_config_info( $script->{server}, "app_id" ),
        PASSWORD          => get_config_info( $script->{server}, "app_pwd" ),
    );
};
$pe->abnormal_exit( CMDMGR_ERROR => $@ ) if $@;

eval { set_command_manager_variables($script) };
$pe->abnormal_exit( CMDMGR_ERROR => $@ ) if $@;

eval { $msi->set_inputfile( $script->{cmdmgr_scp} ) };
$pe->abnormal_exit( CMDMGR_ERROR => $@ ) if $@;

eval {
    $msi->set_resultsfile(
        RESULTSFILE => $script->{cmdmgr_out},
        FAILFILE    => $script->{cmdmgr_nok},
        SUCCESSFILE => $script->{cmdmgr_ok},
    );
};
$pe->abnormal_exit( CMDMGR_ERROR => $@ ) if $@;

my $fh;
open( $fh, ">", $script->{cmdmgr_scp} );
$pe->abnormal_exit( FILE_ERROR => $@ ) if $@;

$log->info("Creating script");
$log->info("Script Keys");
for ( keys %$script ) { $log->info( $_, "\t", $script->{$_} ); }

for my $user (@$result) {
    eval {
        print $fh $msi->add_configuration_ace(
            CONF_OBJECT_TYPE         => "USER",
            OBJECT_NAME              => $user->[1],
            USER_OR_GROUP            => "USER",
            USER_LOGIN_OR_GROUP_NAME => "InsightAdministrator",
            ACCESSRIGHTS             => "FULLCONTROL",
          ),
          "\n";
    };
    $pe->abnormal_exit( CMDMGR_ERROR => $@ ) if $@;
}

$log->info("Sending script to command manager");
eval { $msi->run_script };
$pe->abnormal_exit( CMDMGR_ERROR => $@ ) if $@;

push @{ $script->{all_logs} }, $script->{perl_log};    # add perl log
$pe->set_logs( $script->{all_logs} );
$pe->enable_email_file(1);
$pe->add_exit_status_to_email_subject(1);
$pe->add_exit_type_to_email_message(1);
$pe->set_email_to( get_config_info( $script->{job}, "to" ) );
$pe->set_email_from( get_config_info( $script->{job}, "from" ) );
$pe->set_email_file( $script->{all_logs} );
$pe->set_email_message(
    "Attached are the logs for control m job " . $script->{job} );
$pe->set_email_subject( $script->{job} . " Completed" );
$pe->enable_move_logs(1);
eval {
    $pe->move_logs(
        NEW_LOG_LOCATION => $script->{new_log_location},
        LOG_SUFFIX_LIST  => [qw(.scp .log .cmd .nok .ok)],
    );
};
$pe->abnormal_exit( CMDMGR_ERROR => $@ ) if $@;
$pe->normal_exit;
