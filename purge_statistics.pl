#!/E:/Perl/bin/perl.exe

use strict;
use warnings;
use Config::IniFiles;
use Log::Log4perl;
use Getopt::Long;
use File::Copy;
use Time::Duration;
use Mail::Sender;
use File::Basename;
use Date::Format;
use DBI;

# perl purge_statistics.pl --cfg_file "C:\\iserver1.ini" --job jobname
my $usage
    = "perl purge_statistics.pl --cfg_file configuration_file --job control_m_job_name\n";

#set script variables
my $start_time = time();
my $end_time   = undef;
my $exit_info = { exit_type   => undef,
                  exit_code   => undef,
                  exit_status => undef,
};
my ( $job, $cfg_file );

my $result = GetOptions( "job=s"      => \$job,
                         "cfg_file=s" => \$cfg_file, );

verify_command_line_arguments( $job, $cfg_file );

my $cfg = Config::IniFiles->new( -file => $cfg_file );
if ( !$cfg ) {
    abnormal_exit( { ERROR         => "Config::IniFiles error",
                     ERROR_MESSAGE => "Can't create Config::IniFiles object",
                   }
    );
}

( my $script_name = fileparse( $0, ".pl" ) ) =~ s/.pl//g;
my $local_server     = uc( Win32::NodeName() );
my $iserver          = $cfg->val( $job, "iserver" );
my $perl_log         = $cfg->val( $job, "perl_log" );
my $perl_log_config  = $cfg->val( $job, "perl_log_config" );
my $new_log_location = $cfg->val( $job, "new_log_location" );
my $job_description  = $cfg->val( $job, "description" );
my $dsn              = $cfg->val( $job, "dsn" );
my $db_id            = $cfg->val( $job, "db_id" );
my $db_pwd           = $cfg->val( $job, "db_pwd" );

my $tables = [
    qw(IS_CACHE_HIT_STATS IS_DOCUMENT_STATS IS_DOC_STEP_STATS IS_PROJ_SESS_STATS IS_REPORT_STATS IS_REP_COL_STATS
        IS_REP_MANIP_STATS IS_REP_SEC_STATS IS_REP_SQL_STATS IS_REP_STEP_STATS IS_SCHEDULE_STATS IS_SESSION_STATS)
];

my $file_extensions_for_files_produced_by_script = [qw(.log)];
my @all_logs                                     = ($perl_log);
my $email_options = { enabled => 1,
                      smtp    => $cfg->val( $job, "smtp" ),
                      to      => $cfg->val( $job, "to" ),
                      from    => $cfg->val( $job, "from" ),
                      subject => $job . " Completed",
};
my $move_log_files_options = {
                    enabled      => 1,
                    log_files    => \@all_logs,
                    new_location => $new_log_location,
                    suffixes => $file_extensions_for_files_produced_by_script,
};

#configure logging
Log::Log4perl->init($perl_log_config);
my $log      = Log::Log4perl->get_logger("purge_statistics");
my $appender = Log::Log4perl->appender_by_name("Logfile");

# main
$log->info( "Begin Processing: ", time2str( "%C", $start_time ) );
$log->info( "Control m job: ",    $job );
$log->info( "Script: ",           $script_name );
$log->info( "Local server: ",     $local_server );
$log->info( "I-server: ",         $iserver );
$log->info("Get data from database");
$log->info("Connect to data source $dsn with db_id $db_id");
my $dbh =
    DBI->connect( $dsn, $db_id, $db_pwd,
                  { RaiseError => 1, AutoCommit => 1 } )
    or abnormal_exit( { ERROR         => "DBI connection error",
                        ERROR_MESSAGE => $DBI::errstr
                            . " Connect string: $dsn, $db_id, $db_pwd",
                      }
    );

$log->info("Build and execute sql statements");
my $time_period = "sysdate - 7";
$log->info( "Records will be deleted for this time period: ", $time_period );
for my $table (@$tables) {
    my $sql
        = "SELECT COUNT(*) FROM " 
        . $table
        . " WHERE RECORDTIME < "
        . $time_period;
    $log->debug( "selectrow_array sql: ", $sql );
    my @row = $dbh->selectrow_array($sql)
        or abnormal_exit( { ERROR         => "DBI prepare error",
                            ERROR_MESSAGE => $dbh->errstr,
                          }
        );
    my $count = join( ",", @row );
    $sql = "DELETE FROM " . $table . " WHERE RECORDTIME < " . $time_period;
    $log->debug( "Prepare sql: ", $sql );
    my $sth = $dbh->prepare($sql)
        or abnormal_exit( { ERROR         => "DBI prepare error",
                            ERROR_MESSAGE => $dbh->errstr,
                          }
        );
    $sth->execute
        or abnormal_exit( { ERROR         => "DBI execute error",
                            ERROR_MESSAGE => $dbh->errstr,
                          }
        );
    $log->info( "Deleted ", $count, " rows from table ", $table );
    $sth->finish();
}
$dbh->disconnect();
normal_exit();

#functions

sub get_log_file_name {return $perl_log;}

sub verify_command_line_arguments {
    for (@_) {
        if ( !defined $_ ) {
            print $usage;
            abnormal_exit( {
                        ERROR         => "Missing argument error",
                        ERROR_MESSAGE => "Required argument not defined: $_",
                      }
            );
        }
    }
}

sub move_log_files {
    my $self = shift;
    for my $log_file ( @{ $self->{'log_files'} } ) {
        if ( !-e $log_file ) {
            abnormal_exit( {
                        ERROR         => "file existence test error",
                        ERROR_MESSAGE => "Can't find log file: " . $log_file,
                      }
            );
        }
        my ( $name, $path, $suffix );
        eval {
            ( $name, $path, $suffix )
                = fileparse( $log_file, @{ $self->{'suffixes'} } );
        };
        if ($@) {
            abnormal_exit( { ERROR         => "fileparse error",
                             ERROR_MESSAGE => $@,
                           }
            );
        }
        my $date_time_template = "%Y%m%d_%H%M%S";
        my $new_log_file
            = $name . $suffix . "." . time2str( $date_time_template, time );
        eval {
            $new_log_file
                = File::Spec->catfile( $self->{'new_location'},
                                       $new_log_file );
        };
        if ($@) {
            abnormal_exit( { ERROR         => "File::Spec catfile error",
                             ERROR_MESSAGE => $@,
                           }
            );
        }
        if ( -e $new_log_file ) {
            my $tmp      = "a";
            my $tmp_file = $new_log_file;
            while ( -e $tmp_file ) {
                $tmp_file = $new_log_file . $tmp;
                $tmp++;
            }
            $new_log_file = $tmp_file;
        }
        eval {copy( $log_file, $new_log_file );};
        if ($@) {
            abnormal_exit( { ERROR         => "File move error",
                             ERROR_MESSAGE => $@,
                           }
            );
        }
        eval {unlink $log_file;};
        if ($@) {
            abnormal_exit( { ERROR         => "File unlink error",
                             ERROR_MESSAGE => $@,
                           }
            );
        }

    }
}

sub normal_exit {
    $exit_info->{exit_type}   = "NORMAL";
    $exit_info->{exit_code}   = 0;
    $exit_info->{exit_status} = "SUCCESS";
    $end_time                 = time();
    for ( keys %$exit_info ) {$log->info( "$_ = ", $exit_info->{$_} );}
    $log->info(
          "Process duration = " . duration_exact( $end_time - $start_time ) );
    my $sender = Mail::Sender->new( { smtp => $email_options->{'smtp'},
                                      from => $email_options->{'from'},
                                    }
        )
        or abnormal_exit( { ERROR         => "Mail::Sender error",
                            ERROR_MESSAGE => $Mail::Sender::Error
                          }
        );
    ref( $sender->MailMsg( {
                   to      => $email_options->{'to'},
                   subject => $exit_info->{'exit_status'} . ": "
                       . $email_options->{'subject'},
                   msg => "MicroStrategy control m job " 
                       . $job
                       . " completed successfully at "
                       . ( scalar localtime $end_time )
                       . ".  Job does: "
                       . $job_description . "\n\n"
                       . Log::Log4perl->appender_by_name("STRING")->string(),
                 }
         )
        )
        or abnormal_exit( { ERROR         => "Mail::Sender error",
                            ERROR_MESSAGE => $Mail::Sender::Error,
                          }
        );
    on_exit( $exit_info->{exit_code} );
}

sub abnormal_exit {
    my $error = shift;
    for my $error_key ( keys %$error ) {
        $log->fatal( $error_key, " = ", $error->{$error_key} );
    }
    $exit_info->{exit_type}   = "ABNORMAL";
    $exit_info->{exit_code}   = 1;
    $exit_info->{exit_status} = "FAILURE";
    $exit_info->{recursion}++;
    my @send_logs = grep {-e $_} @all_logs;
    for ( keys %$exit_info ) {$log->info( "$_ = ", $exit_info->{$_} );}
    $end_time = time();
    $log->info(
          "Process duration = " . duration_exact( $end_time - $start_time ) );

    if ( $exit_info->{recursion} > 1 ) {
        exit $exit_info->{exit_code};
    }

    my $sender = Mail::Sender->new( { smtp => $email_options->{'smtp'},
                                      from => $email_options->{'from'},
                                    }
        )
        or abnormal_exit( { ERROR         => "Mail::Sender",
                            ERROR_MESSAGE => $Mail::Sender::Error,
                          }
        );
    ref( $sender->MailFile( {
                   to      => $email_options->{'to'},
                   subject => $exit_info->{'exit_status'} . ": "
                       . $email_options->{'subject'},
                   msg => "MicroStrategy control m job " 
                       . $job
                       . " failed at "
                       . ( scalar localtime $end_time )
                       . ".  Attached are the logs for control m job "
                       . $job
                       . ".  Job does: "
                       . $job_description . "\n\n"
                       . Log::Log4perl->appender_by_name("STRING")->string(),
                   file => \@send_logs,
                 }
         )
        )
        or abnormal_exit( { ERROR         => "Mail::Sender error",
                            ERROR_MESSAGE => $Mail::Sender::Error,
                          }
        );
    on_exit( $exit_info->{exit_code} );
}

sub on_exit {
    my $code = shift;
    move_log_files($move_log_files_options);
    exit $code;
}
