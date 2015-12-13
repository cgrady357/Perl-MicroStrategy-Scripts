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

# perl file_trigger.pl --cfg_file "C:\\iserver.ini" --job jobname
my $usage
    = "perl file_trigger.pl --cfg_file configuration_file --job control_m_job_name\n";

#set script variables
my $start_time = time();
my $end_time   = undef;
my $exit_info = {exit_type   => undef,
                 exit_code   => undef,
                 exit_status => undef,
};
my ( $job, $cfg_file );

my $result = GetOptions( "job=s"      => \$job,
                         "cfg_file=s" => \$cfg_file, );

verify_command_line_arguments( $job, $cfg_file );

my $cfg = Config::IniFiles->new( -file => $cfg_file );
if ( !$cfg ) {
    abnormal_exit( {ERROR         => "Config::IniFiles error",
                    ERROR_MESSAGE => "Can't create Config::IniFiles object",
                   }
    );
}

( my $script_name = fileparse( $0, ".pl" ) ) =~ s/.pl//g;
my $local_host            = uc( Win32::NodeName() );
my $iserver               = $cfg->val( $job, "iserver" );
my $perl_log              = $cfg->val( $job, "perl_log" );
my $perl_log_config       = $cfg->val( $job, "perl_log_config" );
my $trigger               = $cfg->val( $job, "trigger" );
my $daily_control_m_job   = $cfg->val( $job, "daily_control_m_job" );
my $weekly_control_m_job  = $cfg->val( $job, "weekly_control_m_job" );
my $monthly_control_m_job = $cfg->val( $job, "monthly_control_m_job" );
my $job_description       = $cfg->val( $job, "description" );
my $batch_file_directory  = $cfg->val( $job, "batch_file_directory" );

my $email_options = {enabled => 1,
                     smtp    => $cfg->val( $job, "smtp" ),
                     to      => $cfg->val( $job, "to" ),
                     from    => $cfg->val( $job, "from" ),
                     subject => $job . " Completed",
};

#configure logging
Log::Log4perl->init($perl_log_config);
my $log      = Log::Log4perl->get_logger("event_trigger");
my $appender = Log::Log4perl->appender_by_name("Logfile");

# main
$log->info( "*** Begin Processing ", scalar localtime $start_time );
$log->info( "Control m job: ",       $job );
$log->info( "Script: ",              $script_name );
$log->info( "Trigger: ",             $trigger );

my $trigger_exists = check_for_trigger();

if ( !$trigger_exists ) {
    $email_options->{'enabled'} = 0;
    normal_exit();
}

$log->info( "delete trigger file: ", $trigger );
eval {unlink $trigger;};
if ($@) {
    abnormal_exit( {ERROR         => "Unlink error",
                    ERROR_MESSAGE => $@,
                   }
    );
}

my ( $mday, $wday ) = ( localtime( time() ) )[ 3, 6 ];

my $daily_batch_file
    = $batch_file_directory . "\\" . $daily_control_m_job . ".bat";
eval {run_script($daily_batch_file);};
if ($@) {
    abnormal_exit( {ERROR         => "run_script error",
                    ERROR_MESSAGE => $@,
                   }
    );
}

# $wday is the day of the week, with 0 indicating Sunday and 1 indicating Monday
if ( $wday == 1 ) {
    my $weekly_batch_file
        = $batch_file_directory . "\\" . $weekly_control_m_job . ".bat";

    eval {run_script($weekly_batch_file);};
    if ($@) {
        abnormal_exit( {ERROR         => "run_script error",
                        ERROR_MESSAGE => $@,
                       }
        );
    }
}

# $mday is the day of the month, with 1 indicating first of month
if ( $mday == 1 ) {
    my $monthly_batch_file
        = $batch_file_directory . "\\" . $monthly_control_m_job . ".bat";
    eval {run_script($monthly_batch_file);};
    if ($@) {
        abnormal_exit( {ERROR         => "run_script error",
                        ERROR_MESSAGE => $@,
                       }
        );
    }
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

sub check_for_trigger {
    if ( -e $trigger ) {
        $log->info( $trigger, " trigger file found." );
        return 1;
    }
    $log->info( $trigger, " trigger file doesn't exist." );
    return 0;
}

sub run_script {
    my $arg = shift;
    system($arg) == 0
        or abnormal_exit( {ERROR         => "run_script error",
                           ERROR_MESSAGE => "$?\t$!",
                          }
        );
}

sub normal_exit {
    $exit_info->{exit_type}   = "NORMAL";
    $exit_info->{exit_code}   = 0;
    $exit_info->{exit_status} = "SUCCESS";
    $end_time                 = time();
    for ( keys %$exit_info ) {$log->info( "$_ = ", $exit_info->{$_} );}
    $log->info(
          "Process duration = " . duration_exact( $end_time - $start_time ) );
    if ( !$email_options->{'enabled'} ) {exit $exit_info->{exit_code};}
    my $sender = Mail::Sender->new( {smtp => $email_options->{'smtp'},
                                     from => $email_options->{'from'},
                                    }
        )
        or abnormal_exit( {ERROR         => "Mail::Sender error",
                           ERROR_MESSAGE => $Mail::Sender::Error
                          }
        );
    ref( $sender->MailMsg( {to      => $email_options->{'to'},
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
        or abnormal_exit( {ERROR         => "Mail::Sender error",
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
    $log->info(
          "Process duration = " . duration_exact( $end_time - $start_time ) );

    if ( $exit_info->{recursion} > 1 ) {
        exit $exit_info->{exit_code};
    }

    my $sender =
        Mail::Sender->new( {smtp => $email_options->{'smtp'},
                            from => $email_options->{'from'},
                           }
        )
        or abnormal_exit( {ERROR         => "Mail::Sender",
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
                           file => $perl_log,
                          }
         )
        )
        or abnormal_exit( {ERROR         => "Mail::Sender error",
                           ERROR_MESSAGE => $Mail::Sender::Error,
                          }
        );
    exit $exit_info->{exit_code};
}

