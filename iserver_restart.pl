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

# perl iserver_restart.pl --cfg_file "C:\\iserver1.ini" --job jobname
my $usage
    = "perl iserver_restart.pl --cfg_file configuration_file --job control_m_job_name\n";

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
my $msi_service      = "MicroStrategy Intelligence Server";
my $listener         = "MAPING";
my $iserver_log_dir = "C:\\Program Files\\Common Files\\MicroStrategy\\Log\\";
my $max_loops          = $cfg->val( $job, "max_loops" );            #20
my $max_days           = $cfg->val( $job, "max_days" );             #30
my $max_size           = $cfg->val( $job, "max_size" );             #3000000
my $check_md_max_tries = $cfg->val( $job, "check_md_max_tries" );
my $dsn                = $cfg->val( $job, "dsn" );
my $db_id              = $cfg->val( $job, "db_id" );
my $db_pwd             = $cfg->val( $job, "db_pwd" );
my $ps_tools_dir       = $cfg->val( $job, "ps_tools_dir" );
my $date_template      = "%m%d%Y";

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
my $log      = Log::Log4perl->get_logger("iserver_restart");
my $appender = Log::Log4perl->appender_by_name("Logfile");

# main
$log->info( "MicroStrategy I-Server Daily Restart started on ",
            time2str( "%C", $start_time ) );
$log->info( "Control m job: ", $job );
$log->info( "Script: ",        $script_name );
$log->info( "Local server: ",  $local_server );
$log->info( "I-server: ",      $iserver );
check_metadata( { dsn       => $dsn,
                  db_id     => $db_id,
                  db_pwd    => $db_pwd,
                  max_tries => $check_md_max_tries,
                }
);
delete_logs_older_than_max_days( { log_dir   => $iserver_log_dir,
                                   file_list => q(\.bck$),
                                   max_days  => $max_days,
                                 }
);
stop_service( { server => $iserver, service => $listener } );
stop_service( { server => $iserver, service => $msi_service } );

if ( $iserver eq $local_server ) {
    cleanup_procs( {
           process_list => [ "MSTRSVR", "M8MulPrc_32", "MAEXEC", "M8CAHUTL" ],
           kill_proccess_command => $ps_tools_dir . "\\pskill.exe",
           list_process_command  => $ps_tools_dir . "\\pslist.exe",
        }
    );
}
my $iserver_state
    = status_of_service(
     { server => $iserver, service => $msi_service, max_tries => $max_loops, }
    );
if ( $iserver_state eq "STOPPED" ) {
    manage_log_sizes( { server    => $iserver,
                        file_list => ["DSSErrors.log"],
                        log_dir   => $iserver_log_dir
                      }
    );
}

start_service( { server => $iserver, service => $msi_service } );
start_service( { server => $iserver, service => $listener } );

$log->info("move log files");
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

sub sc_command {
    my $self = shift;
    my $sc_commands = {
        query =>
            'Gets the status for a service or lists the status for types of services.',
        queryex =>
            'Gets the extended status for a service or lists the status for types of services.',
        start       => 'Starts a service.',
        pause       => 'Sends a PAUSE control request to a service.',
        interrogate => 'Sends an INTERROGATE control request to a service.',
        continue    => 'Sends a CONTINUE control request to a service.',
        stop        => 'Sends a STOP request to a service.',
        config      => 'Changes the configuration of a service (persistent).',
        description => 'Changes the description of a service.',
        failure     => 'Changes the actions taken by a service upon failure.',
        sidtype     => 'Changes the service SID type of a service.',
        qc          => 'Gets the configuration information for a service.',
        qdescription => 'Gets the description for a service.',
        qfailure     => 'Gets the actions taken by a service upon failure.',
        qsidtype     => 'Gets the service SID type of a service.',
        delete       => 'Deletes a service (from the registry).',
        create       => 'Creates a service (adds it to the registry).',
        control      => 'Sends a control to a service.',
        sdshow       => 'Displays a service security descriptor.',
        sdset        => 'Sets a service security descriptor.',
        showsid =>
            'Displays the service SID string corresponding to an arbitrary name.',
        GetDisplayName => 'Gets the DisplayName for a service.',
        GetKeyName     => 'Gets the ServiceKeyName for a service.',
        EnumDepend     => 'Lists Service Dependencies.',
        boot =>
            '(ok | bad) Indicates whether the last boot should be saved as the last-known-good boot configuration',
        Lock      => 'Locks the Service Database',
        QueryLock => 'Gets the LockStatus for the SCManager Database',
    };
    $log->info( "Action:  ",
                $self->{command},
                " on Service ",
                $self->{service},
                " on server ",
                $self->{server},
                " Description ",
                $sc_commands->{ $self->{command} }
    );
    my $server  = "\\\\" . $self->{server};
    my $service = $self->{service};
    my $command = $self->{command};
    my $result  = {};

    my @sc_info = `sc $server $command "$service"`;
    for my $rec (@sc_info) {
        my ( $key, $value ) = split /:/, $rec;
        next if !defined($value);
        for ( $key, $value ) {
            s/\s+$//;
            s/^\s+//;
            chomp;
        }
        my $aref = [ split /\s+/, $value ];
        $result->{$service}->{$key} = $aref;
    }
    return $result;
}

sub status_of_service {
    my $self    = shift;
    my $service = $self->{service};
    my $server  = $self->{server} || "";

    my %service_states = ( '1' => 'STOPPED',
                           '2' => 'START_PENDING',
                           '3' => 'STOP_PENDING',
                           '4' => 'RUNNING',
                           '5' => 'CONTINUE_PENDING',
                           '6' => 'PAUSE_PENDING',
                           '7' => 'PAUSED',
    );

    my $count = 0;
SERVICE_STATUS: while ( $count < $self->{max_tries} ) {
        my $status = sc_command( { server  => $server,
                                   service => $service,
                                   command => "query"
                                 }
        );
        if ( !defined($status) ) {
            $log->info(   "Unable to get status of service "
                        . $self->{service}
                        . " for server "
                        . $self->{server} );
            $log->info("sleep 30 seconds");
            sleep(30);
            $count++;
            next SERVICE_STATUS;
        }
        else {return $service_states{ $status->{$service}->{STATE}->[0] }}
        abnormal_exit( { ERROR         => "status_of_service error",
                         ERROR_MESSAGE => "Unable to get status of service "
                             . $self->{service}
                             . "after "
                             . $self->{max_tries}
                             . "tries error",
                       }
        );

    }
}

sub stop_service {
    my $self = shift;
    $log->info(   "Stop service "
                . $self->{service}
                . " for server "
                . $self->{server} );
    my $count = 0;
STOP_SERVICE: while ( $count < $max_loops ) {
        $count++;
        my $state = status_of_service( { server    => $self->{server},
                                         service   => $self->{service},
                                         max_tries => $max_loops,
                                       }
        );
        $log->info( "Loop number ", $count, ": ",
                    $self->{service} . " Service is  " . $state );
        for ($state) {
            /STOPPED/ && do {
                last STOP_SERVICE;
            };
            /STOP_PENDING/ && do {
                $log->info("sleeping 60 seconds");
                sleep(60);
                next STOP_SERVICE;
            };
            /RUNNING/ && do {
                sc_command( { server  => $self->{server},
                              service => $self->{service},
                              command => "stop"
                            }
                );
                sleep(30);
            };
        }

    }
    $log->info("Sleeping 10 seconds");
    sleep(10);
}

sub start_service {
    my $self = shift;
    $log->info(   "Start service "
                . $self->{service}
                . " for server "
                . $self->{server} );
    my $count = 0;
START_SERVICE: while ( $count < $max_loops ) {
        $count++;
        my $state = status_of_service( { server    => $self->{server},
                                         service   => $self->{service},
                                         max_tries => $max_loops,
                                       }
        );
        $log->info( "Loop number ", $count, ": ", $self->{service},
                    " Service is  ", $state );
        for ($state) {
            /RUNNING/ && do {
                last START_SERVICE;
            };
            /START_PENDING/ && do {
                $log->info("Sleep 60 seconds");
                sleep(60);
                next START_SERVICE;
            };
            /STOPPED/ && do {
                my $rc = sc_command( { server  => $self->{server},
                                       service => $self->{service},
                                       command => "start",
                                     }
                );
                $log->info("Sleep 30 seconds");
                sleep(30);
            };
        }

    }
    $log->info("Sleep 10 seconds");
    sleep(10);
}

sub delete_logs_older_than_max_days {
    my $self = shift;
    $log->info("check_log_age");
    my ( $filename, $mtime );
    my $file_list = $self->{file_list};
    $log->info("Cleaning up archived log files");
    my $logs_dh;
    eval {opendir( $logs_dh, $self->{log_dir} );};
    if ($@) {
        $log->info(
                  "delete_logs_older_than_max_days: Could not open directory "
                      . $self->{log_dir} );
        return;
    }
    while ( defined( $filename = readdir($logs_dh) ) ) {
        $_ = $filename;
        next if -d $filename;
        if (/$file_list/i) {
            $mtime = int( -M $self->{log_dir} . $filename );
            if ( $mtime > $self->{max_days} ) {
                unlink $self->{log_dir} . $filename;
                $log->info("Deleted: $filename");
            }
        }
    }
}

sub manage_log_sizes {
    my $self = shift;
    $log->info("manage_log_sizes");

    for my $file ( @{ $self->{file_list} } ) {
        my $basename = basename( $file, '.log' );
        $log->info( "Checking $basename log file for " . $self->{server} );
        my $msi_log = $self->{log_dir} . $file;
        $log->info("File => $msi_log");
        my @file_info = stat($msi_log);
        my $size      = $file_info[7];
        $log->info( "Size => " . $file_info[7] );
        if ( $size > $max_size ) {
            my $new_msi_log
                = $basename . "_" . time2str( $date_template, time ) . ".bck";
            $new_msi_log = $self->{log_dir} . $new_msi_log;
            $log->info("Size of $file file exceeds limits ($size)");
            $log->info("New File => $new_msi_log");
            copy( $msi_log, $new_msi_log );
            Delete $msi_log;
        }
        else {
            $log->info("Size of file is OK");
        }
    }
}

sub check_metadata {
    my $self = shift;
    $log->info("Verify that metadata database is up");
    my $dbh;
    my $count;
    while (1) {
        $count++;
        $dbh = DBI->connect( $self->{dsn}, $self->{db_id}, $self->{db_pwd} );
        if ( !$dbh ) {
            $log->info( "Loop Number ", $count,
                        ": The metadata database is not up yet." );
            $log->inof("Sleep 60 seconds");
            sleep(60);
        }
        last if ($dbh);
        if ( $count == $self->{max_tries} ) {
            abnormal_exit( {
                   ERROR => "Max tries limit for checking metadata error",
                   ERROR_MESSAGE =>
                       "The metadata database is not available.  Max tries ",
                   $self->{max_tries}, " limit hit.",
                 }
            );
        }

    }
    $dbh->disconnect;
    $log->info("Metadata database is up");
}

sub cleanup_procs {
    my $self   = shift;
    my $pslist = $self->{list_process_command};
    my $pskill = $self->{kill_process_command};

    $log->info("Cleaning up abandoned processes");

    # Open a pipe to the PsList command for each process we're looking for
    # and walk through the output of the command. We'll skip the first few
    # lines of the command output.
    my $count  = 0;
    my $killed = 0;

    for my $proc ( @{ $self->{process_list} } ) {
        $log->info("Cleaning up $proc");
        my $fh_pipe;
        open( $fh_pipe, "-|", "$pslist $proc" );
        while (<$fh_pipe>) {
            chop;
            next if (/^[\t ]*$/);
            next if (/^PsList/);
            next if (/^Copyright/);
            next if (/^Systems Internals/);
            next if (/^Sysinternals/i);
            next if (/^Process information/);
            next if (/^Name/);

            if (/^process $proc was not found/) {
                $log->info("Process $proc was not found");
                last;
            }
            $count++;
            my @process = split;
            my @ret     = `$pskill $process[1]`;
            for my $line (@ret) {
                chop;
                next if ( $line =~ /^[\t ]*$/ );
                next if ( $line =~ /^PsKill/ );
                next if ( $line =~ /^Copyright/ );
                next if ( $line =~ /^http:\/\/www.sysinternals.com/ );
                if ( $line =~ /Unable to kill process/ ) {
                    $log->info("Unable to kill process");
                    last;
                }
                if ( $line =~ /Process $process[1] killed/ ) {
                    $killed++;
                    $log->info($line);
                    last;
                }
            }
        }
        close($fh_pipe);
    }
    $log->info("$killed of $count processes killed");
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
    for ( keys %$exit_info ) {
        $log->info( "$_ = ", $exit_info->{$_} );
    }
    $log->info(
          "Process duration = " . duration_exact( $end_time - $start_time ) );
    my $sender =
        Mail::Sender->new( { smtp => $email_options->{'smtp'},
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
    exit $exit_info->{exit_code};
}

sub abnormal_exit {
    my $error = shift;
    for ( keys %$error ) {$log->fatal( "$_ = ", $error->{$_} );}
    $exit_info->{exit_type}   = "ABNORMAL";
    $exit_info->{exit_code}   = 1;
    $exit_info->{exit_status} = "FAILURE";
    $exit_info->{recursion}++;
    for ( keys %$exit_info ) {
        $log->info( "$_ = ", $exit_info->{$_} );
    }
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
                       . $job_description . "\n\n"
                       . Log::Log4perl->appender_by_name("STRING")->string(),
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

=head1 SC

DESCRIPTION:
	SC is a command line program used for communicating with the 
	NT Service Controller and services.
USAGE:
	sc <server> [command] [service name] <option1> <option2>...

	The option <server> has the form "\\ServerName"
	Further help on commands can be obtained by typing: "sc [command]"
	Commands:
	  query-----------Queries the status for a service, or 
	                  enumerates the status for types of services.
	  queryex---------Queries the extended status for a service, or 
	                  enumerates the status for types of services.
	  start-----------Starts a service.
	  pause-----------Sends a PAUSE control request to a service.
	  interrogate-----Sends an INTERROGATE control request to a service.
	  continue--------Sends a CONTINUE control request to a service.
	  stop------------Sends a STOP request to a service.
	  config----------Changes the configuration of a service (persistant).
	  description-----Changes the description of a service.
	  failure---------Changes the actions taken by a service upon failure.
	  sidtype---------Changes the service SID type of a service.
	  qc--------------Queries the configuration information for a service.
	  qdescription----Queries the description for a service.
	  qfailure--------Queries the actions taken by a service upon failure.
	  qsidtype--------Queries the service SID type of a service.
	  delete----------Deletes a service (from the registry).
	  create----------Creates a service. (adds it to the registry).
	  control---------Sends a control to a service.
	  sdshow----------Displays a service's security descriptor.
	  sdset-----------Sets a service's security descriptor.
	  showsid---------Displays the service SID string corresponding to an arbitrary name.
	  GetDisplayName--Gets the DisplayName for a service.
	  GetKeyName------Gets the ServiceKeyName for a service.
	  EnumDepend------Enumerates Service Dependencies.

	The following commands don't require a service name:
	sc <server> <command> <option> 
	  boot------------(ok | bad) Indicates whether the last boot should
	                  be saved as the last-known-good boot configuration
	  Lock------------Locks the Service Database
	  QueryLock-------Queries the LockStatus for the SCManager Database
EXAMPLE:
	sc start MyService

QUERY and QUERYEX OPTIONS : 
	If the query command is followed by a service name, the status
	for that service is returned.  Further options do not apply in
	this case.  If the query command is followed by nothing or one of
	the options listed below, the services are enumerated.
    type=    Type of services to enumerate (driver, service, all)
             (default = service)
    state=   State of services to enumerate (inactive, all)
             (default = active)
    bufsize= The size (in bytes) of the enumeration buffer
             (default = 4096)
    ri=      The resume index number at which to begin the enumeration
             (default = 0)
    group=   Service group to enumerate
             (default = all groups)
SYNTAX EXAMPLES
sc query                - Enumerates status for active services & drivers
sc query messenger      - Displays status for the messenger service
sc queryex messenger    - Displays extended status for the messenger service
sc query type= driver   - Enumerates only active drivers
sc query type= service  - Enumerates only Win32 services
sc query state= all     - Enumerates all services & drivers
sc query bufsize= 50    - Enumerates with a 50 byte buffer.
sc query ri= 14         - Enumerates with resume index = 14
sc queryex group= ""    - Enumerates active services not in a group
sc query type= service type= interact - Enumerates all interactive services
sc query type= driver group= NDIS     - Enumerates all NDIS drivers

sc stop WZCSVC

SERVICE_NAME: WZCSVC
        TYPE               : 20  WIN32_SHARE_PROCESS
        STATE              : 3  STOP_PENDING
                                (STOPPABLE,NOT_PAUSABLE,ACCEPTS_SHUTDOWN)
        WIN32_EXIT_CODE    : 0  (0x0)
        SERVICE_EXIT_CODE  : 0  (0x0)
        CHECKPOINT         : 0x1
        WAIT_HINT          : 0xea60

sc query WZCSVC

SERVICE_NAME: WZCSVC
        TYPE               : 20  WIN32_SHARE_PROCESS
        STATE              : 1  STOPPED
                                (NOT_STOPPABLE,NOT_PAUSABLE,IGNORES_SHUTDOWN)
        WIN32_EXIT_CODE    : 0  (0x0)
        SERVICE_EXIT_CODE  : 0  (0x0)
        CHECKPOINT         : 0x0
        WAIT_HINT          : 0x0

sc start WZCSVC

SERVICE_NAME: WZCSVC
        TYPE               : 20  WIN32_SHARE_PROCESS
        STATE              : 2  START_PENDING
                                (NOT_STOPPABLE,NOT_PAUSABLE,IGNORES_SHUTDOWN)
        WIN32_EXIT_CODE    : 0  (0x0)
        SERVICE_EXIT_CODE  : 0  (0x0)
        CHECKPOINT         : 0x0
        WAIT_HINT          : 0x7d0
        PID                : 220
        FLAGS              :

sc query WZCSVC

SERVICE_NAME: WZCSVC
        TYPE               : 20  WIN32_SHARE_PROCESS
        STATE              : 4  RUNNING
                                (STOPPABLE,NOT_PAUSABLE,ACCEPTS_SHUTDOWN)
        WIN32_EXIT_CODE    : 0  (0x0)
        SERVICE_EXIT_CODE  : 0  (0x0)
        CHECKPOINT         : 0x0
        WAIT_HINT          : 0x0

=cut

