#!/usr/bin/perl

use warnings;
use strict;

my $server = `hostname`;
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $postfix  = sprintf( "%d%02d%02d", $year += 1900, ++$mon, $mday ); 
my $prefix = sprintf("%d-%02d-%02d", $year, $mon, $mday);
my $start_time = $prefix . sprintf(" %02d:%02d:%02d", $hour, $min, $sec);
my $control_m_job_name = "m0apdchk41";
my $log_path = "/logs/0ap/production/scripts/";
my $log_file = $log_path . $control_m_job_name . "-" . $postfix . ".log";
my $to = 'craig.grady@sprint.com';
my $app_name = "tomcat web application server - 0ap-production-msirep";

open(my $fh, '>>', $log_file) or die "Could not open file $log_file $!";

my $check = `ps -ef | grep tppadmin | grep 0ap-production-msirep | wc -l`;
my $status;

if ($check){ $status = "running"; } else { $status = "not running"; } 

my $message = $start_time . " " . $app_name  . " " . $status . " on " . $server; 
print $fh $message;

if(!$check) { `tail -1 $log_file | mail -s "$app_name down on $server" $to`;}
