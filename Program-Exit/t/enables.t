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

my @enable_methods = (
    'enable_email_file', 'enable_email_msg',
    'enable_logging',    'enable_move_logs',
);
for my $meth (@enable_methods) {
    can_ok( $foo, $meth );
}

my $logs = [ "log1", "log2" ];
my $mytime = time();

