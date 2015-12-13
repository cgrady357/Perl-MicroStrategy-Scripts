#!/C:/Perl/bin/perl.exe

use strict;
use warnings;
use Mail::Outlook;

my $outlook = new Mail::Outlook();
my $folder = $outlook->folder('Inbox') or die "Can not set folder";

my $message = $folder->first();
while( my $message = $folder->next() ) { 
	next unless $message->Subject() =~ /MicroStrategy Desktop Upgrade/;
	$message->Body =~ /((w|W)\d+)/;
	my $host = $1 || "Not Listed";
	print $message->From(),"\t|", $host, "\n"; }

#for(keys %email) { print $_, "\n"; }

