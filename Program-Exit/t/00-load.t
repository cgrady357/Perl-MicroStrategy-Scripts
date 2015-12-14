#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Program::Exit' );
}

diag( "Testing Program::Exit $Program::Exit::VERSION, Perl $], $^X" );
