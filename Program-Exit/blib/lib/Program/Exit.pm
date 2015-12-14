package Program::Exit;

use warnings;
use strict;
use File::Copy;
use Time::Duration;
use Log::Log4perl qw(get_logger);
use Mail::Sender;
use File::Basename;
use Carp;
use Moose;
use namespace::autoclean;

=head1 NAME

Program::Exit - The Program Exit module

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';
our $log;
our $logger;

=head1 SYNOPSIS

    use Program::Exit;

    my $foo = Program::Exit->new();


=head1 DESCRIPTION

The Program::Exit module provides a standardized way to exit a perl program in a production environment.  Normal production functionality such as email notification, error logging, process duration, etc is provided.

=cut

=head1 FUNCTIONS

=head2 new

$foo = Program::Exit->new();

=cut

sub BUILD {
    my $self = shift;
    $self->set_start_time( time() );
}

has 'start_time' => ( is         => 'rw',
		      reader     => 'get_start_time',
                      writer     => 'set_start_time',
                      lazy_build => 1,
);

has 'end_time' => ( is         => 'rw',
		    reader     => 'get_end_time',
                    writer     => 'set_end_time',
                    lazy_build => 1,
);

has 'log4_perl_logger' => ( is         => 'rw',
                            lazy_build => 1,
                            reader     => 'get_log4_perl_logger',
                            writer     => 'set_log4_perl_logger',
);

has 'recursion' => ( traits     => ['Counter'],
                     is         => 'rw',
                     isa        => 'Num',
                     default    => 0,
                     reader     => 'get_recursion',
                     writer     => 'set_recursion',
                     handles    => {
                                  inc_recursion   => 'inc',
                                  dec_recursion   => 'dec',
                                  reset_recursion => 'reset',
                     }
);

#log_files, suffixes, enabled, new_location
has 'move_log_files_options' => ( traits  => ['Hash'],
                                  is      => 'rw',
                                  isa     => 'HashRef',
                                  lazy    => 1,
                                  builder => '_build_move_log_files_options',
                                  handles => {
                                        set_move_log_files_option => 'set',
                                        get_move_log_files_option => 'get',
                                        has_move_log_files_option => 'exists',
                                  }
);

#type, code, status
has 'program_exit_info' => ( traits     => ['Hash'],
                             is         => 'rw',
                             isa        => 'HashRef',
                             lazy_build => 1,
                             handles    => {
                                          set_program_exit_info => 'set',
                                          get_program_exit_info => 'get',
                             }
);

#file, message, subject, from, to, enabled
has 'email_options' => ( traits  => ['Hash'],
                         is      => 'rw',
                         isa     => 'HashRef',
                         lazy    => 1,
                         builder => '_build_email_options',
                         handles => { set_email_option => 'set',
                                      get_email_option => 'get',
                                      has_email_option => 'exists',
                         }
);

#log_file_name, log_category, enabled
has 'log4perl_options' => ( traits  => ['Hash'],
                            is      => 'rw',
                            isa     => 'HashRef',
                            lazy    => 1,
                            builder => '_build_log4perl_options',
                            handles => { set_log4perl_option => 'set',
                                         get_log4perl_option => 'get',
                                         has_log4perl_option => 'exists',
                            }
);

#error, error message
has 'error' => ( traits     => ['Hash'],
                 is         => 'rw',
                 isa        => 'HashRef',
                 lazy_build => 1,
                 builder    => '_build_error',
                 handles    => {
                              set_error => 'set',
                              get_error => 'get',
                 }
);

sub _build_move_log_files_options {return {};}
sub _build_email_options          {return {};}
sub _build_program_exit_info      {return {};}
sub _build_log4perl_options       {return {};}
sub _build_error                  {return {};}
sub _build_start_time             {return time();}
sub _build_end_time               {return time();}

sub process_duration {
    my $self = shift;
    if ( !$self->has_end_time() ) {
        $self->set_end_time( time());
    }
    return duration_exact( $self->get_end_time() - $self->get_start_time() );
}

sub _build_log4_perl_logger {
    my $self = shift;
    $logger = Log::Log4perl->get_logger("Program::Exit");
}

sub send_email {
    my $self = shift;
    my $sender;
    ref( $sender =
             new Mail::Sender { smtp => $self->get_email_option('smtp'),
                                from => $self->get_email_option('from')
             }
    ) or $self->abnormal_exit( EMAIL_ERROR => $Mail::Sender::Error );
    if ( $self->has_email_option('file') ) {
        ref( $sender->MailFile( {
                       to      => $self->get_email_option('to'),
                       subject => $self->get_program_exit_info('exit_status')
                           . ":"
                           . $self->get_email_option('subject'),
                       msg => $self->get_program_exit_info('exit_type')
                           . " EXIT: "
                           . $self->get_email_option('body'),
                       file => $self->get_email_option('file'),
                     }
             )
        ) or $self->abnormal_exit( EMAIL_ERROR => $Mail::Sender::Error );
    }
    else {
        ref( $sender->MailMsg( {
                       to      => $self->get_email_option('to'),
                       subject => $self->get_program_exit_info('exit_status')
                           . ":"
                           . $self->get_email_option('subject'),
                       msg => $self->get_program_exit_info('exit_type')
                           . " EXIT: "
                           . $self->get_email_option('body'),
                     }
             )
        ) or $self->abnormal_exit( EMAIL_ERROR => $Mail::Sender::Error );
    }
}

sub _build_postfix_for_move_log_files {
    my ( $mday, $mon, $year ) = ( localtime(time) )[ 3, 4, 5 ];
    my $pf = sprintf( "%d%02d%02d", $year += 1900, ++$mon, $mday );  #20060823
    return $pf;
}

sub move_log_files {
    my $self = shift;
    for my $log_file ( @{ $self->get_move_log_files_option('log_files') } ) {
	 if (! -e $log_file) {
		 $self->abnormal_exit( FILE_ERROR => "Can't find log file: " . $log_file );
	 }  
        my ( $name, $path, $suffix );
        eval {
            ( $name, $path, $suffix )
                = fileparse( $log_file,
                             @{  $self->get_move_log_files_option('suffixes')
                                 }
                );
        };
        $self->abnormal_exit( FILE_PARSE_ERROR => $@ ) if $@;
        my $postfix      = _build_postfix_for_move_log_files();
        my $new_log_file = $name . $suffix . "." . $postfix;
        eval { $new_log_file = 
		File::Spec->catfile( 
			$self->get_move_log_files_option( 'new_location'), $new_log_file );
       	};
	$self->abnormal_exit( FILE_SPEC_CATFILE_ERROR => $@ ) if $@;
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
        $self->abnormal_exit( FILE_COPY_ERROR => $@ ) if $@;
    }
}

sub normal_exit {
    my $self = shift;
    $self->set_program_exit_info( exit_type   => "NORMAL" );
    $self->set_program_exit_info( exit_code   => 0 );
    $self->set_program_exit_info( exit_status => "SUCCESS" );
    if ( $logger->is_debug() ) {
        $logger->debug("normal exit");
        $logger->debug(
                  "exit_type: " . $self->get_program_exit_info('exit_type') );
        $logger->debug(
                  "exit_code: " . $self->get_program_exit_info('exit_code') );
        $logger->debug(
              "exit_status: " . $self->get_program_exit_info('exit_status') );
    }
    $self->set_log4perl_option( 'log_category', "info" );
    $self->exit_program;
}

sub abnormal_exit {
    my $self = shift;
    $self->set_error( error_code    => shift );
    $self->set_error( error_message => shift );
    if ( $logger->is_debug() ) {
        $logger->debug("abnormal exit");
        $logger->debug( "error_code: " . $self->get_error('error_code') );
        $logger->debug(
                     "error_message:  " . $self->get_error('error_message') );
    }
    $self->set_program_exit_info( exit_type   => "ABNORMAL" );
    $self->set_program_exit_info( exit_code   => 1 );
    $self->set_program_exit_info( exit_status => "FAILURE" );
    $self->set_log4perl_option( 'log_category', "fatal" );
    if ( $self->has_error('EMAIL_ERROR') ) {
        $self->set_email_option( enabled => 0 );
    }
    $self->exit_program();
}

sub exit_program {
    my $self = shift;
    $logger->info("exit program");
    $self->inc_recursion;
    if ( $self->get_recursion() >= 2 ) {
        # prevent infinite recursion
        exit $self->get_program_exit_info('exit_code');
    }
    $self->set_end_time( time() );
    $logger->info("get_log4perl_option " . $self->get_log4perl_option('enabled'));
    if ( $self->get_log4perl_option('enabled') ) {
        $self->print_program_status_to_log();
        $logger->info("print program status to log");
    }
    $logger->info("get_email_option" . $self->get_email_option('enabled'));
    if ( $self->get_email_option('enabled') ) {
        $self->send_email();
        $logger->info("send email");
    }
    $logger->info("get_move_log_files_option" . $self->get_move_log_files_option('enabled'));
    if ( $self->get_move_log_files_option('enabled') ) {
        $self->move_log_files();
        $logger->debug("move log files");
    }
    my $exit_code = $self->get_program_exit_info('exit_code');
    exit $exit_code;
}

sub print_program_status_to_log {
    my $self         = shift;
    my $log_category = $self->get_log4perl_option('log_category');

    if ( $self->has_error('error_code') ) {
        $logger->$log_category( "Error = " . $self->get_error('error_code') );
        $logger->$log_category(
                     "Error Message = " . $self->get_error('error_message') );
    }

    $logger->$log_category(
                 "Exit Type = " . $self->get_program_exit_info('exit_type') );
    $logger->$log_category(
                 "Exit Code = " . $self->get_program_exit_info('exit_code') );
    $logger->$log_category(
             "Exit Status = " . $self->get_program_exit_info('exit_status') );
    $logger->$log_category(
                      "Process duration = " . $self->process_duration() );
}

=head1 AUTHOR

Craig Grady, C<< <cgrady357 at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-program-exit at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Program-Exit>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Program::Exit


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Program-Exit>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Program-Exit>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Program-Exit>

=item * Search CPAN

L<http://search.cpan.org/dist/Program-Exit/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2010 Craig Grady.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

no Moose;
__PACKAGE__->meta->make_immutable;

1;    # End of Program::Exit
