#!/C:/Perl/bin/perl.exe

use strict;
use warnings;
use DBI;
use File::Copy;
use Mail::Sender;
my $desktop = 1; # 1 when running from desktop, 0 when running from server
no warnings 'once';

my $config_path = "D:\\Prod_D\\0AP\\Application\\MicroStrategy";
my ($mday,$mon,$year) = (localtime(time))[3,4,5];
my $postfix = sprintf("%d%02d%02d",$year += 1900 ,++$mon, $mday); #20060823
my $start_time = time();

my $q = '"';
my $exit_code;
#mail variables
my $to = 'SFWINF-EUSRPTOPS@sprint.com';
my $from = 'admin@' . Win32::NodeName() . '.corp.sprint.com';

my $log_dir = "D:\\Prod_D\\0AP\\Logs\\MicroStrategy";
my $cmdmgr_dir = "D:\\MicroStrategy\\Administrator\\Comman~1";

if($desktop) {
$config_path = "C:\\Prod_D\\0AP\\Application\\MicroStrategy";
$log_dir = "C:\\Prod_D\\0AP\\Logs\\MicroStrategy";
$cmdmgr_dir = "C:\\PROGRA~1\\MicroStrategy\\Administrator\\Comman~1";
$to = 'craig.grady@sprint.com';
}

my $cmdmgr_exe  = $cmdmgr_dir . "\\CMDMGR.exe";
my $cmdmgr_script = $log_dir . "\\arch_rpt.scp";
my $cmdmgr_results_log = $log_dir . "\\archive_reports_OP_results.log";
my $cmdmgr_fail_log = $log_dir . "\\archive_reports_OP_fail.log";
my $cmdmgr_success_log = $log_dir . "\\archive_reports_OP_success.log";
my $perl_log = $log_dir . "\\archive_reports_OP.log";

my %sql = (
#get metadata report list
md_reps => qq { select object_id from dssmdobjinfo where object_type=3 and create_time <= (sysdate-180) and project_id = (select object_id from dssmdobjinfo where object_type=32 and object_name='Operational and Performance')  }, 
#get project id
project_id => qq { select b.IS_PROJ_ID from IS_PROJ b where b.IS_PROJ_NAME = 'OPERATIONAL AND PERFORMANCE' },   
#get report details
rep_details => qq { select a.is_rep_id ,a.IS_REP_NAME, a.EM_OWNER_NAME, a.IS_REP_LOC from is_rep a where a.IS_REP_GUID=? and a.is_proj_id=? and a.is_rep_loc like ?},   
#find out if the report has been run in the past 6 months
exec_date => qq { select a.is_proj_id, a.IS_REP_ID from IS_REP_FACT a WHERE a.IS_REP_EXEC_REQ_TS >=TO_DATE(SYSDATE-180, 'DD-MM-YYYY') AND a.IS_PROJ_ID=? AND a.is_rep_id=? group by a.is_proj_id, a.IS_REP_ID },   
 );

{ package Connstr; require "$config_path\\archive_reports_OP.cfg"; }

open LOG, "> $perl_log" or abnormal_exit("Cannot open log file $perl_log", $!, $?);

#subs

#ALTER REPORT "<report_name>" IN FOLDER "<location_path>" [ENABLECACHE (TRUE | FALSE | DEFAULT)] [NAME "<new_report_name>"] [LONGDESCRIPTION "<new_long_description>"] [DESCRIPTION "<new_description>"]  [FOLDER "<new_location_path>"] [HIDDEN (TRUE | FALSE)] FOR PROJECT "<project_name>";

sub archive_cmd { 
	my ($rep, $loc, $new_loc, $proj) = @_; 
	$loc =~ s/IS:\\OPERATIONAL AND PERFORMANCE//; 
	$loc =~ s/\\$rep$//g; #location includes report name, must drop to use in script
	(my $prefix = $loc) =~ s/[\\]/zz/g;
	my $new_rpt_name = $prefix . "zz" . $rep . "zz" . $postfix;
	return "ALTER REPORT ", $q, $rep, $q, " IN FOLDER ", $q, $loc,  $q, " NAME " , $q, $new_rpt_name, $q, " FOLDER ", $q, $new_loc, $q, " FOR PROJECT ", $q, $proj, $q, ";";
};

my $cmdmgr = sub { 
#	cmdmgr -n ProjectSourceName -u Username [-p Password] [-f InputFile [-o OutputFile | -break | -or ResultsFile -of FailFile -os SuccessFile] [-i] [-h] [-showoutput] [-stoponerror] [-skipsyntaxcheck] [-e]]
	my ($cmd, $proj_src, $login, $passwd, $cmd_mgr_script, $results_out, $fail_out, $success_out) = @_;
	write_log("$cmd -n \"$proj_src\" -u $login -p $passwd -f $cmd_mgr_script -or $results_out -of $fail_out -os $success_out");
	system("$cmd -n \"$proj_src\" -u $login -p $passwd -f $cmd_mgr_script -or $results_out -of $fail_out -os $success_out")==0 or abnormal_exit($!, $?);  
};

my $create_script = sub {
        my ($file, $usr_info) = @_;
	write_log("Create command manager script");
	my $fh;
	open($fh, ">", $file) or abnormal_exit ("Could not open file: $file", $!, $?);
	for(@{$usr_info}) {


		my $arch = join("",(archive_cmd(@$_, '\Public Objects\Archive\Public Reports',"Operational and Performance")));
		print $fh $arch,  "\n";
		write_log($arch);
	}
	close $fh;
};

my $run_script = sub {
        my ($cmd, $conn, $results_log, $fail_log, $success_log, $script) = @_;
	if(-e $results_log) { unlink $results_log or abnormal_exit("Could not delete file: $results_log", $!, $?); }
	if(-e $fail_log) { unlink $fail_log or abnormal_exit("Could not delete file: $fail_log", $!, $?); }
	if(-e $success_log) { unlink $success_log or abnormal_exit("Could not delete file: $success_log", $!, $?); }
	write_log("Sending script to command manager");
	&$cmdmgr($cmd, @{$conn}, $script, $results_log, $fail_log, $success_log);
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
	my ($to, $from, $subject, $msg, $file) = @_;
	my $sender;
	ref ($sender = new Mail::Sender {from => $from}) or abnormal_exit("$Mail::Sender::Error\n");
	(ref ($sender->MailFile({to => $to, subject => $subject, msg => $msg, file => $file}))) or abnormal_exit("$Mail::Sender::Error\n");
}

sub write_log {   
      	my $mytime = localtime;
	print LOG $mytime, "|", @_, "\n" or abnormal_exit("Cannot write to log file $perl_log", $!, $?);
};

sub abnormal_log {
  # This function should only be called by abnormal_exit().
  # It exists because abnormal_exit() would cause infinite recursion if
  # it used write_log() and encountered an error when printing.
  my $mytime = localtime;
  print LOG $mytime, "|", @_, "\n" or print "$_[0]\nCannot write to log file $perl_log:\n  $!\n";
}

sub normal_exit {
  my $log = $_[0];
  my $ptime = &$proc_time;
  my $subject = "Archive O&P reports script completed successfully.";
  my $msg = "Attached you will find the archive_reports.pl logs";
  write_log("Total process time: $ptime");
  write_log("Normal exit with status=0");
  close LOG;
  
  my ($mday,$mon,$year) = (localtime(time))[3,4,5];
  my $postfix = sprintf("%d%02d%02d",$year += 1900 ,++$mon, $mday); #20060823

  move($log, "$log.$postfix");     
  	  
  #send_email($to, $from, $subject , $msg, [ $perl_log, $cmdmgr_log ]);
  exit 0;
}

sub abnormal_exit {
  my ($message, $code) = @_;
  abnormal_log($message);
  if($code) { $exit_code = $code;} else { $exit_code = 1;};

  my $ptime = &$proc_time;
  abnormal_log("Total process time: $ptime");
  abnormal_log("Abnormal exit with status=$exit_code");

  close LOG;
  my $subject = "Archive O&P reports script aborted due to error.";
  my $msg = "Attached you will find the archive_reports_OP.pl logs";
  #send_email($to, $from, $subject, $msg, [ $perl_log, $cmdmgr_log ]);

  exit $exit_code;
}

#main
my $db_con = $Connstr::connstr{OLAP75};
my $dbh = DBI->connect(@{$db_con}, { RaiseError => 1, AutoCommit => 1 }) or abnormal_exit ($DBI::errstr . " Connect string: " . join(" ", @{$db_con}));
#get metadata report list
my $sth = $dbh->prepare($sql{md_reps}) or abnormal_exit($dbh->errstr);
$sth->execute or abnormal_exit($dbh->errstr);
my $md_reps = $sth->fetchall_arrayref();
#get project id
$sth = $dbh->prepare($sql{project_id}) or abnormal_exit($dbh->errstr);
$sth->execute or abnormal_exit($dbh->errstr);
my $proj_id = $sth->fetchall_arrayref();
$proj_id = $proj_id->[0]->[0];
#get report details
$sth = $dbh->prepare($sql{rep_details}) or abnormal_exit($dbh->errstr);
my %reports;
my $loc = 'IS:\OPERATIONAL AND PERFORMANCE\PUBLIC OBJECTS\REPORTS\%';
for my $r(@$md_reps) { 
	#is_rep_id, is_rep_name, em_owner_name, is_rep_loc, guid
	$sth->execute($$r[0], $proj_id, $loc) or abnormal_exit($dbh->errstr); 
	my $q = $sth->fetchall_arrayref();
	if($q->[0]->[0]) { $reports{$$r[0]} = [ $q->[0]->[0], $q->[0]->[1], $q->[0]->[2], $q->[0]->[3] ]; }	
}
#find out if the report has been run in the past 6 months
my %archive_list;
$sth = $dbh->prepare($sql{exec_date}) or abnormal_exit($dbh->errstr);
while( my($key, $value) = each(%reports)) {
	$sth->execute($proj_id, $value->[0] ) or abnormal_exit($dbh->errstr); 
	my $x = $sth->fetchall_arrayref();
	if($x->[0]->[0]) { $archive_list{$key}++; }
}
$sth->finish();
$dbh->disconnect();
while( my($key, $value) = each(%archive_list)) { print join(" ", @{$reports{$key}}); }

#&$create_script($cmdmgr_script, $archive_list);
#&$run_script($cmdmgr_exe, $Connstr::login{msi1}, $cmdmgr_results_log, $cmdmgr_fail_log, $cmdmgr_success_log, $cmdmgr_script);
#normal_exit($perl_log);
