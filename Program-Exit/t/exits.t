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

my @exit_methods = ( 'exit_program', 'normal_exit', 'abnormal_exit', );
for my $meth (@exit_methods) {
    can_ok( $foo, $meth );
}

