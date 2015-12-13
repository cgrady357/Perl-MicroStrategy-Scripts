#!/D:/Perl/bin/perl.exe

use strict;
use warnings;
use Config::IniFiles;
use Business::Intelligence::MicroStrategy::CommandManager;
use Log::Log4perl;
use Getopt::Long;
use File::Copy;
use Time::Duration;
use Mail::Sender;
use File::Basename;
use DBI;

# perl event_trigger.pl --cfg_file "C:\\iserver1.ini" --job jobname
my $usage
    = "perl event_trigger.pl --cfg_file configuration_file --job control_m_job_name\n";

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
my $local_host       = uc( Win32::NodeName() );
my $iserver          = $cfg->val( $job, "iserver" );
my $perl_log         = $cfg->val( $job, "perl_log" );
my $perl_log_config  = $cfg->val( $job, "perl_log_config" );
my $new_log_location = $cfg->val( $job, "new_log_location" );
my $job_description  = $cfg->val( $job, "description" );
my $dsn              = $cfg->val( $job, "dsn" );
my $db_id            = $cfg->val( $job, "db_id" );
my $db_pwd           = $cfg->val( $job, "db_pwd" );
my $sql_file         = $cfg->val( $job, "sql_file" );
my $target_acl_group = $cfg->val( $job, "target_acl_group" );
my $cmdmgr_dir       = $cfg->val( $local_host, "cmdmgr_dir" );
my $cmdmgr_exe       = $cfg->val( $local_host, "cmdmgr_exe" );
my @file_extensions_for_command_manager = (qw(scp out nok ok));
my $cmdmgr                              = {};

for my $ext (@file_extensions_for_command_manager) {
    $cmdmgr->{$ext} = $cmdmgr_dir . "\\" . $job . "." . $ext;
    if ( -e $cmdmgr->{$ext} ) {
        eval {unlink $cmdmgr->{$ext};};
        if ($@) {
            abnormal_exit( { ERROR         => "Unlink error",
                             ERROR_MESSAGE => $@,
                           }
            );
        }
    }
}
my $file_extensions_for_files_produced_by_script
    = [qw(.scp .log .out .nok .ok)];
my @all_logs = values %$cmdmgr;
push @all_logs, $perl_log;
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
my $log      = Log::Log4perl->get_logger("event_trigger");
my $appender = Log::Log4perl->appender_by_name("Logfile");

# main
$log->info( "*** Begin Processing ", scalar localtime $start_time );
$log->info( "Control m job: ",       $job );
$log->info( "Script: ",              $script_name );

$log->info("Get data from database");

$log->info("Load sql files");
my $sql = {};
for my $record ( split /;/, $sql_file ) {
    my ( $sql_name, $sql_statement ) = split /#/, $record;
    $sql->{$sql_name}->{"text"} = get_sql_file_text($sql_statement);
}

$log->info("Connect to data source $dsn with db_id $db_id");
my $dbh = DBI->connect( $dsn, $db_id, $db_pwd )
    or abnormal_exit( { ERROR         => "DBI error",
                        ERROR_MESSAGE => $DBI::errstr
                            . " Connect string: $dsn, $db_id, $db_pwd",
                      }
    );

for my $sql_name ( keys %$sql ) {
    $log->info( "Prepare sql: " . $sql->{$sql_name}->{"text"} );
    my $sth = $dbh->prepare( $sql->{$sql_name}->{"text"} )
        or abnormal_exit( { ERROR         => "DBI prepare error",
                            ERROR_MESSAGE => $dbh->errstr,
                          }
        );
    $log->info("execute sql");
    $sth->execute
        or abnormal_exit( { ERROR         => "DBI execute error",
                            ERROR_MESSAGE => $dbh->errstr,
                          }
        );
    $sql->{$sql_name}->{"result_set"} = $sth->fetchall_arrayref();
    $sth->finish();
}
$dbh->disconnect();

$log->info("Begin Command Manager section");
my $msi = Business::Intelligence::MicroStrategy::CommandManager->new;
eval {$msi->set_cmdmgr_exe($cmdmgr_exe)};
if ($@) {
    abnormal_exit( { ERROR         => "set_cmdmgr_exe error",
                     ERROR_MESSAGE => $@,
                   }
    );
}

eval {
    $msi->set_connect(
              PROJECTSOURCENAME => $cfg->val( $job,     "projectsourcename" ),
              USERNAME          => $cfg->val( $iserver, "app_id" ),
              PASSWORD          => $cfg->val( $iserver, "app_pwd" ),
    );

};
if ($@) {
    abnormal_exit( { ERROR         => "set_connect error",
                     ERROR_MESSAGE => $@,
                   }
    );
}

eval {$msi->set_inputfile( $cmdmgr->{'scp'} )};
if ($@) {
    abnormal_exit( { ERROR         => "set_inputfile error",
                     ERROR_MESSAGE => $@,
                   }
    );
}

eval {
    $msi->set_resultsfile( RESULTSFILE => $cmdmgr->{'out'},
                           FAILFILE    => $cmdmgr->{'nok'},
                           SUCCESSFILE => $cmdmgr->{'ok'},
    );
};
if ($@) {
    abnormal_exit( { ERROR         => "set_resultsfile error",
                     ERROR_MESSAGE => $@,
                   }
    );
}

my $fh;
open( $fh, ">", $cmdmgr->{scp} )
    or abnormal_exit( {
        ERROR         => "open file error",
        ERROR_MESSAGE => "File " . $cmdmgr->{scp} . " unable to open: " . $!,
      }
    );

$log->info("Creating script");

for my $sql_name ( keys %$sql ) {
    if ( !defined( $sql->{$sql_name}->{"result_set"}->[1] ) ) {last;}
    my ( $project, $user_name, $user_id )
        = @{ $sql->{$sql_name}->{"result_set"}->[1] };
    eval {
        print $fh $msi->create_user_profile( USER     => $user_id,
                                             LOCATION => "\\Profiles",
                                             PROJECT  => $project
            ),
            "\n";
    };
    if ($@) {
        abnormal_exit( { ERROR         => "create_user_profile error",
                         ERROR_MESSAGE => $@,
                       }
        );
    }

    eval {
        print $fh $msi->add_folder_ace(
                                FOLDER                   => $user_name,
                                LOCATION                 => "\\Profiles",
                                USER_OR_GROUP            => "GROUP",
                                USER_LOGIN_OR_GROUP_NAME => $target_acl_group,
                                ACCESSRIGHTS             => "FULLCONTROL",
                                CHILDRENACCESSRIGHTS     => "FULLCONTROL",
                                PROJECT                  => $project
            ),
            "\n";
    };
    if ($@) {
        abnormal_exit( { ERROR         => "add_folder_ace error",
                         ERROR_MESSAGE => $@,
                       }
        );
    }

    eval {
        print $fh $msi->alter_folder_acl( FOLDER              => $user_name,
                                          LOCATION            => "\\Profiles",
                                          PROPAGATE_OVERWRITE => "TRUE",
                                          RECURSIVELY         => "TRUE",
                                          PROJECT             => $project
            ),
            "\n";
    };
    if ($@) {
        abnormal_exit( { ERROR         => "alter_folder_ace error",
                         ERROR_MESSAGE => $@,
                       }
        );
    }
}

$log->info("Sending script to command manager");
eval {$msi->run_script()};
if ($@) {
    abnormal_exit( { ERROR         => "run_script error",
                     ERROR_MESSAGE => $@,
                   }
    );
}

eval {move_log_files($move_log_files_options);};
if ($@) {
    abnormal_exit( { ERROR         => "move_log_files error",
                     ERROR_MESSAGE => $@,
                   }
    );
}
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

sub get_sql_file_text {
    my $file_to_load = shift;
    my $sql_fh;
    open( $sql_fh, "<", $file_to_load )
        or abnormal_exit( {ERROR         => "Can't open file error",
                           ERROR_MESSAGE => "Can't open file: $file_to_load",
                         }
        );
    my $sql_text = do {local ($/); <$sql_fh>}
        or abnormal_exit( {ERROR         => "Can't read file error",
                           ERROR_MESSAGE => "Can't read file: $file_to_load",
                         }
        );
    close $sql_fh;
    return $sql_text;
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
        my ( $mday, $mon, $year ) = ( localtime(time) )[ 3, 4, 5 ];
        my $postfix
            = sprintf( "%d%02d%02d", $year += 1900, ++$mon, $mday ); #20060823
        my $new_log_file = $name . $suffix . "." . $postfix;
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
            abnormal_exit( { ERROR         => "File copy error",
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
    ref( $sender->MailMsg( { to      => $email_options->{'to'},
                             subject => $exit_info->{'exit_status'} . ": "
                                 . $email_options->{'subject'},
                             msg => "MicroStrategy control m job " 
                                 . $job
                                 . " completed successfully at "
                                 . ( scalar localtime $end_time )
                                 . ".  Job does: "
                                 . $job_description,
                           }
         )
        )
        or abnormal_exit( { ERROR         => "Mail::Sender error",
                            ERROR_MESSAGE => $Mail::Sender::Error,
                          }
        );
    exit $exit_info->{exit_code};
}

sub abnormal_exit {
    my $error = shift;
    for ( keys %$error ) {$log->fatal( "$_ = ", $error->{$_} );}
    $exit_info->{exit_type}   = "ABNORMAL";
    $exit_info->{exit_code}   = 1;
    $exit_info->{exit_status} = "FAILURE";
    $exit_info->{recursion}++;
    for ( keys %$exit_info ) {$log->info( "$_ = ", $exit_info->{$_} );}
    $end_time = time();
    my @send_logs = grep {-e $_} @all_logs;
    $log->info(
          "Process duration = " . duration_exact( $end_time - $start_time ) );

    if ( $exit_info->{recursion} > 1 ) {
        exit $exit_info->{exit_code};
    }

    my $sender =
        Mail::Sender->new( { smtp => $email_options->{'smtp'},
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
                              . $job_description,
                          file => \@send_logs,
                        }
         )
        )
        or abnormal_exit( { ERROR         => "Mail::Sender error",
                            ERROR_MESSAGE => $Mail::Sender::Error,
                          }
        );
    exit $exit_info->{exit_code};
}

