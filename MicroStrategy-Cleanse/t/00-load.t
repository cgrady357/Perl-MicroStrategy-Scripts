#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'MicroStrategy::Cleanse' );
}

diag( "Testing MicroStrategy::Cleanse $MicroStrategy::Cleanse::VERSION, Perl $], $^X" );
