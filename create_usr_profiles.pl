#!/C:/Perl/bin/perl.exe
use lib "C:\\code\\perl\\";
use Shared::Process_time;

my $config_path = "C:\\cfg";
{ package Connstr; require "$config_path\\msi.cfg"; }

my @usr_grps =  ("Web - PCS");


#main
my $pt = Process_time::new();
my $usr_cmd;
for(@usr_grps) { $usr_cmd .= list_usr($_); }
exe_cmd_mgr($usr_cmd, "grp_memb.scp", "grp_memb.log");
my $usr_list = get_usr("grp_memb.log");
my $profile_cmd;
for(keys %$usr_list) { $profile_cmd .= usr_profile($_, "PCS Handset Exchange"); } 
exe_cmd_mgr($profile_cmd, "profile.scp", "profile.log");
print "Process Time: ", $pt->Process_time::proc_time(), "\n";

#subs
sub list_usr { return "LIST MEMBERS FOR USER GROUP \"$_[0]\";\n"; }
sub usr_profile { return "CREATE USER PROFILE FOR USER \"$_[0]\" FOR PROJECT \"$_[1]\";\n"; } 
sub exe_cmd_mgr {
	my ($cmd, $script, $log) = @_;
	my $fh;
	open($fh, ">$script") or die("Couldn't open file: $script", $!, $?);
	print $fh $cmd;
	close($fh);
	run_cmdmgr(@{$Connstr::login{msi1}}, $script, $log);
}

sub get_usr {
	my $log = shift;
	my $fh;
	open($fh,"<$log") or die("Couldn't open file: $log $!", $?);
	my %usr = ();
	while(my $line = <$fh>){ 
		chomp $line;
		my($tmp, $keep) = split(/\=/, $line);
		my @users = split( /\)\,/, $keep);
		for(@users) {/(\w+)\s+(.*)/; $usr{$1} = $2;}
	}
	close($fh);
	return \%usr;
}


sub run_cmdmgr {
  system("cmdmgr -n \"$_[0]\" -u $_[1] -p $_[2] -f $_[3] -o $_[4] -s")==0 or die("Could not launch Command manager:\n $!", $?); 
	    
}
