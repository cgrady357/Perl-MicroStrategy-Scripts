#!/D:/Perl/bin/perl.exe

use strict;
use warnings;
use DBI;
use File::Copy;
use Mail::Sender;
my $desktop = 0; # 1 when running from desktop, 0 when running from server

#'Connstr::connstr', 'Connstr::login'; these variables used only once, this is ok
no warnings 'once';

#globals
my $start_time = time();
my $sql_usr_list = q{ select distinct a11.EM_USER_ABBREV, a11.EM_USER_NAME 
from	EM_USER	a11, 
	IS_USR_GP_USER	a12, 
	EM_USR_GP	a13
where	a11.EM_USER_ID = a12.EM_USER_ID and 
	a11.EM_EXISTS_ID = a13.EM_EXISTS_ID and 
	a12.EM_USR_GP_ID = a13.EM_USR_GP_ID
 and	(a11.EM_ENABLED = 1 and a13.EM_USR_GP_ABBREV in ('DASHBOARD DEVELOPERS', 'DASHBOARD WEB USERS',
'DASHBOARD - BFA/SLA ADMIN','DASHBOARD -INCIDENT MANAGEMENT','DASHBOARD DESKTOP','DASHBOARD SAMC',
'DASHBOARD WEB VIEW ONLY','DASHBOARD-ESC SCHEDULING','EDS - VIEW ONLY','IBM - VIEW ONLY','WEB ADMIN - DASHBOARD',
'WEB - DASHBOARD','DASHBOARD ITS DEVELOPERS','WEB ADMIN - OPERATIONAL AND PERFORMANCE','ARCHITECT ITS DASHBOARD',
'WEB - NON IT PROJECT REPORTING'))
 and    a11.EM_CREATE_DATE > (sysdate - 8) 
};
my $q = '"';

my $config_path = "D:\\Prod_D\\0AP\\Application\\MicroStrategy";
my $log_dir = "D:\\Prod_D\\0AP\\Logs\\MicroStrategy";
my $cmdmgr_dir = "D:\\MicroStrategy\\Administrator\\Comman~1";

my $cmdmgr_exe  = $cmdmgr_dir . "\\CMDMGR.exe";
my $cmdmgr_script = $cmdmgr_dir . "\\ace.scp";
my $cmdmgr_log = $log_dir . "\\ace.log";
my $perl_log = $log_dir . "\\add_acls.log";

my $exit_code;
#mail variables
my $to = 'SFWINF-EUSRPTOPS@sprint.com';
my $from = 'admin@' . Win32::NodeName() . '.corp.sprint.com';

if($desktop) {
$config_path = "C:\\Prod_D\\0AP\\Application\\MicroStrategy";
$log_dir = "C:\\Prod_D\\0AP\\Logs\\MicroStrategy";
$cmdmgr_dir = "C:\\PROGRA~1\\MicroStrategy\\Administrator\\Comman~1";
$cmdmgr_exe  = $cmdmgr_dir . "\\CMDMGR.exe";
$cmdmgr_script = $cmdmgr_dir . "\\ace.scp";
$cmdmgr_log = $log_dir . "\\ace.log";
$perl_log = $log_dir . "\\add_acls.log";
$to = 'craig.grady@sprint.com';
};

{ package Connstr; require "$config_path\\add_acls.cfg"; }

my $logfh;
open $logfh, "> $perl_log" or abnormal_exit("Cannot open log file $perl_log", $!, $?);


#subs
my $get_usr_list = sub {
	my ($db_con, $sql) = @_;
	my $dbh = DBI->connect(@{$db_con}) or abnormal_exit ($DBI::errstr . " Connect string: " . join(" ", @{$db_con}));
	my $sth = $dbh->prepare($sql) or abnormal_exit($dbh->errstr);
	$sth->execute or abnormal_exit($dbh->errstr);
	my $result = $sth->fetchall_arrayref();
	$sth->finish();
	$dbh->disconnect();
	return $result;
};

my $create_user_profile = sub { return "CREATE USER PROFILE ", $q, $_[0], $q, " FOR PROJECT ", $q, $_[1], $q, ";"; };

my $ace = sub { return "ADD ACE FOR FOLDER ", $q, $_[0], $q, " IN FOLDER ", $q, "\\Profiles",  $q,
	      " GROUP ", $q, $_[1], $q, " ACCESSRIGHTS FULLCONTROL CHILDRENACCESSRIGHTS FULLCONTROL FOR PROJECT ",
	      $q, $_[2], $q, ";";
};

my $propagate = sub { return "ALTER ACL FOR FOLDER ", $q, $_[0], $q, " IN FOLDER ", $q, "\\Profiles", $q, 
	      " PROPAGATE OVERWRITE RECURSIVELY FOR PROJECT ", $q, $_[1], $q, ";";
};

my $cmdmgr = sub { 
	my ($cmd, $proj_src, $login, $passwd, $cmd_mgr_script, $out) = @_;
	write_log("$cmd -n \"$proj_src\" -u $login -p xxxxx -f $cmd_mgr_script -o $out");
	system("$cmd -n \"$proj_src\" -u $login -p $passwd -f $cmd_mgr_script -o $out"); 
};

my $create_script = sub {
        my ($file, $usr_info) = @_;
	write_log("Create command manager script");
	open(FH, ">", $file) or abnormal_exit ("Could not open file: $file", $!, $?);
	for(@{$usr_info}) {
		my $profile = join("",(&$create_user_profile(${$_}[0], "Operational and Performance")));
		print FH $profile,  "\n";
		write_log($profile);
		my $grp = join("",(&$ace(${$_}[1], "Dashboard Desktop","Operational and Performance")));
		print FH $grp,  "\n";
		write_log($grp);
		my $grp2 = join("",(&$ace(${$_}[1], "Dashboard ITS Developers","Operational and Performance")));
		print FH $grp2, "\n";
		write_log($grp2);
		my $prop = join("",(&$propagate(${$_}[1], "Operational and Performance")));
		print FH $prop,  "\n";
		write_log($prop);
	}
	close FH;
};

my $run_script = sub {
        my ($cmd, $conn, $log, $script) = @_;
	if(-e $log) { unlink $log or abnormal_exit("Could not delete file: $log", $!, $?); }
	write_log("Sending script to command manager");
	&$cmdmgr($cmd, @{$conn}, $script, $log);
};

my $proc_time = sub {
  my $tot_time = time() - $start_time;

  my $tot_hour = int(($tot_time / 60) / 60);
  $tot_time    = $tot_time - ($tot_hour * 60 * 60);
  my $tot_min  = int($tot_time / 60);
  my $tot_sec  = $tot_time - ($tot_min * 60);

  if($tot_hour > 1) { $tot_time = "$tot_hour hours "; } 
  elsif($tot_hour == 1) { $tot_time = "1 hour "; } 
  else { $tot_time = ""; }

  if($tot_min > 1) { $tot_time = "$tot_time $tot_min minutes "; } 
  elsif($tot_min == 1) { $tot_time = "$tot_time 1 minute "; }

  if($tot_sec > 1) { $tot_time = "$tot_time $tot_sec seconds"; } 
  elsif($tot_sec == 1) { $tot_time = "$tot_time 1 second"; }
  return $tot_time;
};

sub send_email {
	exit if $desktop;
	my ($to, $from, $subject, $msg, $file) = @_;
	my $sender;
	ref ($sender = new Mail::Sender {from => $from}) or abnormal_exit("$Mail::Sender::Error\n");
	(ref ($sender->MailFile({to => $to, subject => $subject, msg => $msg, file => $file}))) or abnormal_exit("$Mail::Sender::Error\n");
}

sub write_log {   
      	my $mytime = localtime;
	print $logfh $mytime, "|", @_, "\n" or abnormal_exit("Cannot write to log file $perl_log", $!, $?);
};

sub abnormal_log {
  # This function should only be called by abnormal_exit().
  # It exists because abnormal_exit() would cause infinite recursion if
  # it used write_log() and encountered an error when printing.
  my $mytime = localtime;
  print $logfh $mytime, "|", @_, "\n" or print "$_[0]\nCannot write to log file $perl_log:\n  $!\n";
}

sub normal_exit {
  my $log = $_[0];
  my $log2 = $_[1];
  my $ptime = &$proc_time;
  write_log("Total process time: $ptime");
  write_log("Normal exit with status=0");
  close $logfh;
  
  my ($mday,$mon,$year) = (localtime(time))[3,4,5];
  my $postfix = sprintf("%d%02d%02d",$year += 1900 ,++$mon, $mday); #20060823

  copy($log, "$log.$postfix");     
  copy($log2, "$log2.$postfix");
  
  my $subject = "Add ACLs script completed successfully.";
  my $msg = "Attached you will find the add_acls.pl logs";
  send_email($to, $from, $subject, $msg, [ $perl_log, $cmdmgr_log ]);
  exit 0;
}

sub abnormal_exit {
  my ($message, $code) = @_;
  abnormal_log($message);
  if($code) { $exit_code = $code;} else { $exit_code = 1;};

  my $ptime = &$proc_time;
  abnormal_log("Total process time: $ptime");
  abnormal_log("Abnormal exit with status=$exit_code");

  close $logfh;
  my $subject = "Add ACLs script encountered an error.";
  my $msg = "Attached you will find the add_acls.pl logs";
  send_email($to, $from, $subject, $msg, [ $perl_log, $cmdmgr_log ]);

  exit $exit_code;
}

#main
my $usr_list = &$get_usr_list($Connstr::connstr{OLAP75}, $sql_usr_list);
&$create_script($cmdmgr_script, $usr_list);
&$run_script($cmdmgr_exe, $Connstr::login{msi1}, $cmdmgr_log, $cmdmgr_script);
normal_exit($perl_log, $cmdmgr_log);

