#!/C:/Perl/bin/perl.exe
# by Craig Grady
# created 1/18/06
# modified 8/25/06
# applies security filters to users in the ES&D Reports projects
use Getopt::Std;
use lib "C:\\Documents and Settings\\cgrady04\\My Documents\\code\\perl\\Shared";
use Shared::Process_time;

my $usage= qq{
Insufficient arguments.

Usage:
% apply_sec_filter.pl -l	#labor
% apply_sec_filter.pl -p	#payroll
% apply_sec_filter.pl -c	#cost center
% apply_sec_filter.pl -o	#organizational

};

die($usage) if (@ARGV == 0) ;
getopts('lpco');

my $config_path = "C:\\Documents and Settings\\cgrady04\\My Documents\\code\\perl\\cfg";
-e $config_path or die("Config path incorrect $config_path");
{ package Connstr; do "$config_path\\msi.cfg"; }

sub list_usr;
sub get_usr;
sub run_cmdmgr;
sub apply_filters;
sub normal_exit;
sub abnormal_exit;

my ($name, $grp, $proj);
#"esdlabcc", "ESDLABCC", "ES&D Labor Reports"
if($opt_l) { ($name, $grp, $proj) = ("esdlabcc", "ESDLABCC", "ES&D Labor Reports"); }
if($opt_p) { ($name, $grp, $proj) = ("esdpayorg", "ESDPAYORG", "ES&D Payroll Reports"); }
if($opt_c) { ($name, $grp, $proj) = ("esdtecc", "ESDTECC", "ES&D T&E Reports - Cost Center Security"); }
if($opt_o) { ($name, $grp, $proj) = ("esdteorg", "ESDTEORG", "ES&D T&E Reports - Organizational Security"); }

#main
my $pt = Process_time::new();
list_usr("$name.scp", "$name.log", $grp);
my $usr_list = get_usr("$name.log");
apply_filters("$name-apply.scp", "$name-apply.log", $usr_list, $proj)
print "Process Time: ", $pt->Process_time::proc_time(), "\n";
normal_exit;

sub list_usr {
	my ($script, $log, $grp_name) = @_;
	my $fh;
	open($fh, ">$script") or abnormal_exit("Couldn't open file: $script $!", $?);
	print $fh "LIST MEMBERS FOR USER GROUP \"$grp_name\";";
	close($fh);
	run_cmdmgr(@{$Connstr::login{tpp2}}, $script, $log);
	exit;
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


sub apply_filters {
	my ($script, $log, $usr, $proj_name) = @_;
	open($fh, ">$script") or abnormal_exit("Couldn't open file: $script $!", $?);
	for(keys %$usr) {
		my $sec_filter = $_;
		my $dir1 = substr($_,0,3);
		my $dir2 = substr($_,3,1);
		my $dir3 = substr($_,4,1);
		my $loc_path = "\\Public Objects\\Security Filters\\$dir1\\$dir2\\$dir3";
		my $user = $_;
		print $fh "APPLY SECURITY FILTER \"$sec_filter\" FOLDER \"$loc_path\" TO USER \"$user\" ON PROJECT \"$proj_name\";\n";
	}
	close($fh);
	#&run_cmdmgr(@{$Connstr::login{tpp2}}, $script, $log);
}


sub run_cmdmgr {
  system("cmdmgr -n \"$_[0]\" -u $_[1] -p $_[2] -f $_[3] -o $_[4] -s")==0 or abnormal_exit("Could not launch Command manager:\n $!", $?); 
	    
}

sub normal_exit { exit 0; }
sub abnormal_exit { print($_[0]); $exit_code = $_[1] or $exit_code = 1; exit $exit_code; }
