#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Business::Intelligence::MicroStrategy::CommandManager::NCS' );
}

diag( "Testing Business::Intelligence::MicroStrategy::CommandManager::NCS $Business::Intelligence::MicroStrategy::CommandManager::NCS::VERSION, Perl $], $^X" );
