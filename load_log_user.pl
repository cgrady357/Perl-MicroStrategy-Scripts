#!/C:/Perl/bin/perl.exe

use strict;
use warnings;
use DBI();
use Log::Log4perl;
use Config::IniFiles;
use Getopt::Long;
use File::Copy;
use Time::Duration;
use Mail::Sender;
use File::Basename;
use Date::Calc::Object qw(:all);

# Normal dsserrors log record has 7 fields
#0			       1              2         3         4       5         6
#2010-04-19 14:50:54.758-06:00 [HOST:XXXXXXX][PID:7116][THR:6168][Kernel][Warning] Project 'REVUSG_NEW' has been switched from 'Offline' to 'Active'
# A dsserrors log error record has 8 fields
#0			       1              2         3         4              5      6            7
#2010-04-19 15:55:36.651-06:00 [HOST:XXXXXXXX][PID:7116][THR:7672][Report Server][Error][0x00000225] Report cache is not found.

# perl event_trigger.pl --cfg_file "C:\\iserver1.ini" --job jobname
my $usage
    = "perl load_log_user.pl --cfg_file configuration_file --job control_m_job_name\n";

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
my $local_host         = uc( Win32::NodeName() );
my $iserver            = $cfg->val( $job, "iserver" );
my $perl_log           = $cfg->val( $job, "perl_log" );
my $perl_log_config    = $cfg->val( $job, "perl_log_config" );
my $new_log_location   = $cfg->val( $job, "new_log_location" );
my $job_description    = $cfg->val( $job, "description" );
my $dsserrors_log      = $cfg->val( $job, "dsserrors_log" );
my $sql_file           = $cfg->val( $job, "sql_file" );
my $dsn                = $cfg->val( $job, "dsn" );
my $db_id              = $cfg->val( $job, "db_id" );
my $db_pwd             = $cfg->val( $job, "db_pwd" );
my $start_date_file    = $cfg->val( $job, "start_date_file" );
my $start_date_pattern = qr/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})/;
my $parse_dsserrors_log_pattern
    = qr/(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}.\d{1,4}-\d{2}:\d{2}).\[HOST:(\w+)\]\[PID:(\d{1,5})\]\[THR:(\d{1,5})\]\[(\w+\s??\w+?)\]\[(\w+)\](.*)/;
my $parse_dsserrors_error_code_field_pattern = qr/\[(\w{10})\]/;

my $email_options = { enabled => 1,
                      smtp    => $cfg->val( $job, "smtp" ),
                      to      => $cfg->val( $job, "to" ),
                      from    => $cfg->val( $job, "from" ),
                      subject => "$job  Completed",
};

my $file_extensions_for_files_produced_by_script
    = [qw(.scp .log .out .nok .ok)];
my $move_log_files_options = {
                    enabled      => 1,
                    log_files    => [$perl_log],
                    new_location => $new_log_location,
                    suffixes => $file_extensions_for_files_produced_by_script,
};

#configure logging
Log::Log4perl->init($perl_log_config);
my $log      = Log::Log4perl->get_logger("load_log");
my $appender = Log::Log4perl->appender_by_name("Logfile");

# main
$log->info( "*** Begin Processing ", scalar localtime $start_time );
$log->info( "Control m job: ",       $job );
$log->info( "Script: ",              $script_name );

$log->info("Connect to data source $dsn with db_id $db_id");
my $dbh = DBI->connect( $dsn, $db_id, $db_pwd )
    or abnormal_exit( { ERROR         => "DBI error",
                        ERROR_MESSAGE => $DBI::errstr
                            . " Connect string: $dsn, $db_id, $db_pwd",
                      }
    );

$log->info("Get start date from start date file");
my $start_date = get_start_date();

$log->info("Load sql file");
my $sql = get_sql_file_text($sql_file);

$log->info("Prepare sql: $sql");
my $sth = $dbh->prepare($sql)
    or abnormal_exit( { ERROR         => "DBI prepare error",
                        ERROR_MESSAGE => $dbh->errstr,
                      }
    );

if ( -e "$dsserrors_log.bak" ) {
    $log->info("Load $dsserrors_log.bak");
    load_records("$dsserrors_log.bak");
}
if ( -e "$dsserrors_log.bak00" ) {
    $log->info("Load $dsserrors_log.bak00");
    load_records("$dsserrors_log.bak00");
}
$log->info("Load $dsserrors_log");
my $new_start_date = load_records($dsserrors_log);

$log->info("Write new start date: $new_start_date");
write_new_start_date_to_file($new_start_date);

$sth->finish();
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

sub get_start_date {
    my $start_date_file_fh;
    my ( $start_year, $start_month, $start_day,
         $start_hour, $start_min,   $start_sec );

    if ( -e $start_date_file ) {
        open( $start_date_file_fh, "<", $start_date_file )
            or abnormal_exit( {
                 ERROR         => "File open error",
                 ERROR_MESSAGE => "Unable to open file $start_date_file: $?",
               }
            );

        while ( my $line = <$start_date_file_fh> ) {
            (  $start_year, $start_month, $start_day,
               $start_hour, $start_min,   $start_sec
            ) = ( $line =~ /$start_date_pattern/ );
        }
        close $start_date_file_fh;
    }
    if (    !defined($start_year)
         || !defined($start_month)
         || !defined($start_day)
         || !defined($start_hour)
         || !defined($start_min)
         || !defined($start_sec) ) {
        $log->info("ERROR:  Start date field not defined error");
        $log->info(
                 "Will use get_start_date.sql to get start date information");
        $log->info("Load sql file");
        my $start_date_sql_file = $cfg->val( $job, "start_date_sql_file" );
        my $start_date_sql = get_sql_file_text($start_date_sql_file);

        $log->info("Prepare sql: $start_date_sql");
        my $sth = $dbh->prepare($start_date_sql)
            or abnormal_exit( { ERROR         => "DBI prepare error",
                                ERROR_MESSAGE => $dbh->errstr,
                              }
            );
        $sth->execute()
            or abnormal_exit( { ERROR         => "DBI execute error",
                                ERROR_MESSAGE => $dbh->errstr,
                              }
            );
        ( my $start_date_string ) = $sth->fetchrow_array;
        (  $start_year, $start_month, $start_day,
           $start_hour, $start_min,   $start_sec
        ) = ( $start_date_string =~ /$start_date_pattern/ );

    }

    my $get_start_date_dt =
        Date::Calc->new( $start_year, $start_month, $start_day,
                         $start_hour, $start_min,   $start_sec );
    if ( !$get_start_date_dt->is_valid() ) {
        abnormal_exit( { ERROR         => "Date::Calc not valid error",
                         ERROR_MESSAGE => "Date::Calc start date not valid "
                             . "\nDateTime fields: "
                             . " start_year: "
                             . $start_year
                             . " start_month: "
                             . $start_month
                             . " start_day: "
                             . $start_day
                             . " start_hour: "
                             . $start_hour
                             . " start_min: "
                             . $start_min
                             . " start_sec: "
                             . $start_sec,
                       }
        );
    }

    return $get_start_date_dt;
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

sub load_records {
    my $dss_errors_log_fh;
    my $load_file = shift;

    open( $dss_errors_log_fh, "<", $load_file )
        or abnormal_exit( {
                       ERROR         => "File open error",
                       ERROR_MESSAGE => "Can't open file $load_file, $?, $!",
                     }
        );

    my ( $log_date, $host, $pid, $thr, $component, $status, $err_no );
DSSERRORS_LOG_RECORDS:
    while ( my $line = <$dss_errors_log_fh> ) {
        if ( $line =~ /# MicroStrategy/ ) {next DSSERRORS_LOG_RECORDS;}
        chomp $line;
        my $error_no;
        my @match = ( $line =~ /$parse_dsserrors_log_pattern/ );
        if ( @match > 0 ) {
            (  my ( $log_year, $log_month, $log_day,
                    $log_hour, $log_min,   $log_sec
               )
            ) = ( $match[0] =~ /$start_date_pattern/ );
            my $compare_date =
                Date::Calc->new( $log_year, $log_month, $log_day,
                                 $log_hour, $log_min,   $log_sec );
            if ( !$compare_date->is_valid() ) {
                abnormal_exit( {
                       ERROR => "Date::Calc compare_date is not valid error",
                       ERROR_MESSAGE =>
                           "Date::Calc compare_date is not valid error",
                     }
                );
            }
            if ( $compare_date lt $start_date ) {
                next DSSERRORS_LOG_RECORDS;
            }

            if ( defined $match[5] && $match[5] eq 'Error' ) {
                ($error_no)
                    = ( $match[6]
                        =~ /$parse_dsserrors_error_code_field_pattern/ );
            }
            $sth->execute( @match[ 0 .. 5 ], $error_no, $match[6] )
                or abnormal_exit( { ERROR         => "DBI execute error",
                                    ERROR_MESSAGE => $dbh->errstr,
                                  }
                );
            ( $log_date, $host, $pid, $thr, $component, $status )
                = @match[ 0 .. 5 ];
            $err_no = $error_no;
        }
        else {
            $sth->execute( $log_date, $host, $pid, $thr, $component, $status,
                           $err_no, $line )
                or abnormal_exit( { ERROR         => "DBI execute error",
                                    ERROR_MESSAGE => $dbh->errstr,
                                  }
                );
        }
    }
    close $dss_errors_log_fh;
    return $log_date;
}

sub write_new_start_date_to_file {
    my $last_log_record_date = shift;
    my $start_date_file_fh;

    open( $start_date_file_fh, ">", $start_date_file )
        or abnormal_exit( {
                 ERROR         => "File open error",
                 ERROR_MESSAGE => "Unable to open file $start_date_file: $?",
               }
        );

    print $start_date_file_fh $last_log_record_date, "\n";
    close $start_date_file_fh;
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

sub move_log_files_on_exit {
    $log->info("move log files");
    eval {move_log_files($move_log_files_options);};
    if ($@) {
        abnormal_exit( { ERROR         => "move_log_files error",
                         ERROR_MESSAGE => $@,
                       }
        );
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
    move_log_files_on_exit();
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
                              . $job_description,
                          file => [$perl_log],
                        }
         )
        )
        or abnormal_exit( { ERROR         => "Mail::Sender error",
                            ERROR_MESSAGE => $Mail::Sender::Error,
                          }
        );
    move_log_files_on_exit();
    exit $exit_info->{exit_code};
}

