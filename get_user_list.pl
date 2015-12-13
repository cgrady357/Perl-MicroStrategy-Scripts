#!/C:/Perl/bin/perl.exe

use strict;
use warnings;
use lib "C:\\code\\perl";
use Shared::Process_time;
use Shared::Cmd_mgr;

my $config_path = "C:\\code\\perl\\cfg";
{ package Connstr; require "$config_path\\msi.cfg"; }

my $pt = Process_time::new();

my $q = '"';
my $list_grp = sub { return "LIST GROUPS;"; };
my $list_usr = sub { return "LIST MEMBERS FOR USER GROUP ", $q, $_[0], $q, ";\n"; };


#args:  proj_src, cmd_mgr_login, msi_server_passwd, cmd_mgr_script, output file
my $cmdmgr = sub { system("cmdmgr -n \"$_[0]\" -u $_[1] -p $_[2] -f $_[3] -o $_[4] -s")==0 
		 or die("Could not launch Command manager:\n $!", $?);  
};

my $script1 = "groups.scp";
my $fh;
open($fh, ">$script1") or die ($!, $?);
print $fh (&$list_grp); 
close $fh;

my $log1 = "user_groups.log";
&$cmdmgr(@{$Connstr::login{msi1}}, $script1, $log1);



my @grps;
open($fh, $log1) or die ($!, $?);
while(my $line = <$fh>) { 
	next unless $line =~ /Group/; 
	chomp $line; 
	(undef, my $grp) = split("= ", $line); 
	push @grps, $grp; 
}
close $fh;

my $script2 = "user.scp";
open($fh, ">$script2") or die ($!, $?);
for(@grps) { print $fh (&$list_usr($_)); }
close $fh;

my $log2 = "user_list.log";
&$cmdmgr(@{$Connstr::login{msi1}}, $script2, $log2);

unlink $script1, $script2;
