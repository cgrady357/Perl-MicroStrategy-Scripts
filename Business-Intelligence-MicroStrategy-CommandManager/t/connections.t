use strict;
use warnings;

use Test::More qw/no_plan/;

use lib '..';

BEGIN { use_ok('Business::Intelligence::MicroStrategy::CommandManager'); }

ok(
    my $foo = Business::Intelligence::MicroStrategy::CommandManager->new(),
    'can create object Business::Intelligence::MicroStrategy::CommandManager'
);

# And now to test the methods/subroutines.

ok ($foo->set_connect("project_source_name", "userid", "password"), 'can call $foo->set_connect("project_source_name", "userid", "password")');
ok ($foo->set_inputfile("test.scp"), 'can call $foo->set_inputfile("test.scp")');
ok ($foo->set_resultsfile("results.log", "fail.log", "success.log"), 'can call $foo->set_resultsfile("results.log", "fail.log", "success.log")');
ok ($foo->set_cmdmgr_exe("path_to_executable"), 'can call $foo->set_cmdmgr_exe("path_to_executable")');
ok ($foo->get_cmdmgr_exe, 'can call $foo->get_cmdmgr_exe');
ok ($foo->set_connect("project_source_name", "userid", "password"), 'can call $foo->set_connect("project_source_name", "userid", "password")');
ok ($foo->set_project_source_name("project_source_name"), 'can call $foo->set_project_source_name("project_source_name")');
ok ($foo->set_user_name("user_name"), 'can call $foo->set_user_name("user_name")');
ok ($foo->set_password("foobar"), 'can call $foo->set_password("foobar")');
ok ($foo->get_connect, 'can call $foo->get_connect');
ok ($foo->set_inputfile("input_file"), 'can call $foo->set_inputfile("input_file")');
ok ($foo->get_inputfile, 'can call $foo->get_inputfile');
ok ($foo->set_outputfile("output_file"), 'can call $foo->set_outputfile("output_file")');
ok ($foo->get_outputfile, 'can call $foo->get_outputfile');
ok ($foo->set_resultsfile("results.out","fail.out","success.out"), 'can call $foo->set_resultsfile("results.out","fail.out","success.out")');
ok ($foo->get_resultsfile, 'can call $foo->get_resultsfile');
ok ($foo->set_instructions, 'can call $foo->set_instructions');
ok ($foo->set_header, 'can call $foo->set_header');
ok ($foo->set_showoutput, 'can call $foo->set_showoutput');
ok ($foo->set_stoponerror, 'can call $foo->set_stoponerror');
ok ($foo->set_skipsyntaxcheck, 'can call $foo->set_skipsyntaxcheck');
ok ($foo->set_error, 'can call $foo->set_error');
ok ($foo->set_break, 'can call $foo->set_break');
