use strict;
use warnings;
use Program::Exit;
use Moose -metaclass => 'Program::Exit';

my $pe = Program::Exit->new();
my @methods = $pe->get_all_methods;
my @attrs = $pe->get_all_attributes; 

print "methods\n", join("\n", @methods);
print "attributes\n", join("\n", @attrs);
