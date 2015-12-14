#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw/no_plan/;

BEGIN {
    use_ok('File::Copy');
    use_ok('Time::Duration');
    use_ok('Log::Log4perl');
    use_ok('Mail::Sender');
    use_ok('File::Basename');
    use_ok('Carp');
    use_ok('Program::Exit');
    use_ok('Cwd');
    use_ok('File::Spec');
}

ok( my $pe = Program::Exit->new(), 'can create object Program::Exit' );
isa_ok( $pe, 'Program::Exit', 'object $pe' );

my $pe_logs = [ "pe_log1", "pe_log2" ];
my $mytime = time();

ok (    $pe->set(
		EXIT_TYPE => "ABNORMAL",
	    EXIT_CODE    => 1,
	    EXIT_STATUS  => "FAILURE",
	    LOG_CATEGORY => "FATAL", 
    ), '$pe->set(
		EXIT_TYPE => "ABNORMAL",
	    EXIT_CODE    => 1,
	    EXIT_STATUS  => "FAILURE",
	    LOG_CATEGORY => "FATAL", 
    )');
 

my %set_methods_w_args = (
   set_logger => File::Spec->catfile( getcwd() , "t", "log.cfg" ),          
    set_email_file => $pe_logs,
    set_email_from => "j.beam\@cpan.org",      
    set_email_message => "Tasting results",
    set_email_subject => "Whiskey tasting",   
    set_email_to => "j.daniel\@cpan.org",
    set_exit_code => "1",
    set_exit_status => "NORMAL",     
    set_exit_type => "SUCCESS",
    set_logs => $pe_logs,
    set_start_time => $mytime,
);

my @set_methods_no_args = qw( set_end_time  set_processing_time );

for my $meth (keys %set_methods_w_args) {
    my $args =$set_methods_w_args{$meth};
    my $test_name = "can call " . $meth . " with args " . $args;
    ok($pe->$meth($args), $test_name);
}

