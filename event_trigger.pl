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

# perl event_trigger.pl --cfg_file "C:\\iserver.ini" --job jobname
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
eval {print $fh $msi->trigger_event( $cfg->val( $job, "event_name" ) ), "\n";};
if ($@) {
    abnormal_exit( { ERROR         => "trigger_event error",
                     ERROR_MESSAGE => $@,
                   }
    );
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
                          file => \@all_logs,
                        }
         )
        )
        or abnormal_exit( { ERROR         => "Mail::Sender error",
                            ERROR_MESSAGE => $Mail::Sender::Error,
                          }
        );
    exit $exit_info->{exit_code};
}