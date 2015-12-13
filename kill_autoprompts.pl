#!/C:/Perl/bin/perl.exe
# by Craig Grady
# Date Created:  03/09/2009

#use strict;
use warnings;
no warnings 'once';
use aliased 'Business::Intelligence::MicroStrategy::CommandManager' => 'Cmdmgr';
use Text::Balanced qw(extract_bracketed extract_multiple);

#globals
my $config_path =
  "C:\\code\\perl\\cfg";
{ package Connstr; require "$config_path\\msi_desktop.cfg"; }

my ( $script, $out, $not_ok, $ok );
my $iserver = "npr1";
my $exe     = Cmdmgr->new;
my $fh;

#subs
sub map_names {
    $name   = shift;
    $script = $name . ".scp";
    open( $fh, ">", $script ) or die( $!, $? );
    $exe->set_inputfile($script);
    ( $out, $not_ok, $ok ) = map { $name . $_; } ( ".log", ".nok", ".ok" );
    $exe->set_resultsfile(
        RESULTSFILE => $out,
        FAILFILE    => $not_ok,
        SUCCESSFILE => $ok
    );
}

#main

$exe->set_connect(
    PROJECTSOURCENAME => $Connstr::connstr{$iserver}->[0],
    USERNAME          => $Connstr::connstr{$iserver}->[1],
    PASSWORD          => $Connstr::connstr{$iserver}->[2]
);

map_names("listjobs");
print $fh $exe->list_jobs( TYPE => "ALL" ), "\n";
$exe->run_script;

my @jobs;
open( $fh, "<", $out ) or die( $!, $? );
while ( my $line = <$fh> ) {
    next unless $line =~ /WAITING_FOR_AUTOPROMPT/;

#3/9/2009 6:23:29 PM   JOB ID = 11761 (User: #####, ######) (Status: WAITING_FOR_AUTOPROMPT) (Description: Running report Total Usage by BAN)
    my @result = extract_multiple( $line, [ \&extract_bracketed, '()', ] );
    grep { s/[()]//g } @result;
    my $job;
    ( undef, $job ) = ( split /= /, $result[0] );
    push @jobs, [ $job, $result[1], $result[3], $result[5] ];
}

map_names("jobprops");
for (@jobs) { print $fh $exe->list_job_properties( $$_[0] ), "\n"; }
$exe->run_script;

=head1 list_job_properties output
3/10/2009 1:20:27 PM   Job ID = 16469
3/10/2009 1:20:27 PM   Creation Time = 3/10/2009 1:15:40 PM
3/10/2009 1:20:27 PM   Description = Running report Home
3/10/2009 1:20:27 PM   Job Status = WAITING_FOR_AUTOPROMPT
3/10/2009 1:20:27 PM   Machine Name = Server Machine: ###.###.###.### Client Machine: ##.#.##.###
3/10/2009 1:20:27 PM   Owner = #####, #####
3/10/2009 1:20:27 PM   Priority = Low
3/10/2009 1:20:27 PM   Project ID = 4
3/10/2009 1:20:27 PM   Project Name = Integrated Sales and Churn (RIS

=cut

my $jobprops = {};

open( $fh, $out ) or die( $!, $? );
my $job_id = "";
while (<$fh>) {
    chomp;
    /Job ID = / && do {
        ( undef, $job_id ) = split /= /, $_;
        $jobprops->{$job_id}->{JOB_ID} = $job_id;
    };
    /Creation Time = /
      && do { ( undef, $jobprops->{$job_id}->{CREATION_TIME} ) = split /= /, $_; };
    /Description = /
      && do { ( undef, $jobprops->{$job_id}->{DESCRIPTION} ) = split /= /, $_; };
    /Job Status = /
      && do { ( undef, $jobprops->{$job_id}->{JOB_STATUS} ) = split /= /, $_; };
    /Machine Name = /
      && do { ( undef, $jobprops->{$job_id}->{MACHINE_NAME} ) = split /= /, $_; };
    /Owner = /
      && do { ( undef, $jobprops->{$job_id}->{OWNER} ) = split /= /, $_; };
    /Priority = /
      && do { ( undef, $jobprops->{$job_id}->{PRIORITY} ) = split /= /, $_; };
    /Project ID = /
      && do { ( undef, $jobprops->{$job_id}->{PROJECT_ID} ) = split /= /, $_; };
    /Project Name = /
      && do { ( undef, $jobprops->{$job_id}->{PROJECT_NAME} ) = split /= /, $_; };
}

map_names("killjobs");
for my $job ( keys %$jobprops ) {
    next if $jobprops->{$job}->{PROJECT_NAME} !~ /Integrated Sales and Churn/;
    print $fh $exe->kill_job( JOB => $job ), "\n";
}

$exe->run_script;

