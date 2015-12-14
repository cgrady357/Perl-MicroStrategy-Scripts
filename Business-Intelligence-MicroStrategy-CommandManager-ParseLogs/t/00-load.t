#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Business::Intelligence::MicroStrategy::CommandManager::ParseLogs' );
}

diag( "Testing Business::Intelligence::MicroStrategy::CommandManager::ParseLogs $Business::Intelligence::MicroStrategy::CommandManager::ParseLogs::VERSION, Perl $], $^X" );
