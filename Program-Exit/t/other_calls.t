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
}

ok( my $foo = Program::Exit->new(), 'can create object Program::Exit' );
isa_ok( $foo, 'Program::Exit', 'object $foo' );

my @other_methods = (
    'add_exit_status_to_email',       'add_exit_status_to_email_subject',
    'add_exit_type_to_email_message', 'email_file',
    #   'email_msg',                      
    'move_logs', 'log_status',
);

for my $meth (@other_methods) {
    can_ok( $foo, $meth );
}

my $logs = [ "log1", "log2" ];
my $mytime = time();


