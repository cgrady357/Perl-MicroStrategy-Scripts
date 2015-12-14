package Business::Intelligence::MicroStrategy::CommandManager::ParseLogs;

use warnings;
use strict;
use Carp;
use Regexp::Common;

=head1 NAME

Business::Intelligence::MicroStrategy::CommandManager::ParseLogs - The great new Business::Intelligence::MicroStrategy::CommandManager::ParseLogs!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Business::Intelligence::MicroStrategy::CommandManager::ParseLogs;

    my $foo = Business::Intelligence::MicroStrategy::CommandManager::ParseLogs->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 FUNCTIONS

=head2 new

my $foo = Business::Intelligence::MicroStrategy::CommandManager::ParseLogs->new;

=cut

sub new {
	my $class = shift;
	my $self = {};
	bless ($self, $class);
	return $self;
}

=head2 list_projects

$foo->list_projects;

=cut

sub list_projects {
	my $self = shift;
	return keys %{$self->{PROJECT_LIST}};
}




=head2 parse_list_projects

$foo->parse_list_projects(FILE => $file);

=cut

sub parse_list_projects { 
	my $self = shift;
	my %parms = @_;
	@$self{keys %parms} = values %parms;
	my ($fh, @projs);
	open($fh, $self->{FILE}) or croak("Unable to open " . $self->{FILE} . ": $?, $!");
	while(my $line = <$fh>) { 
		next unless $line =~ /Project =/; 
		chomp $line; 
		(undef, my $keep) = split("= ", $line);
		#5/8/2009 2:32:30 PM   Project = (SAIL) Integrated Service Level Activity Engine (Registered) (Load at startup: YES) (Status: Loaded)
		my ($proj, $registered, $load_at_startup, $status) = ($keep =~ /^(.*)\s\((.*)\)\s\((.*)\)\s\((.*)\)$/);
		$self->{PROJECT_LIST}->{$proj}->{REGISTERED} = $registered;
		$load_at_startup =~ s/Load at startup: //;
		$status =~ s/Status: //;
		$self->{PROJECT_LIST}->{$proj}->{LOAD_AT_STARTUP} = $load_at_startup;
		$self->{PROJECT_LIST}->{$proj}->{STATUS} = $status;
	}
	close $fh;
}

=head2 parse_dbs

$foo->parse_dbs(FILE => $file);

=cut

sub parse_dbs {
	#LIST DBINSTANCES
	#3/18/2008 11:17:17 AM   DBInstance = DH_WORK_TBLS (NCO Projects)
	my $self = shift;
	my %parms = @_;
	@$self{keys %parms} = values %parms;
	my ($fh, %names);
	open($fh, $self->{FILE}) or croak("Unable to open " . $self->{FILE} . ": $?, $!");
	while(my $line = <$fh>) { 
		next unless $line =~ /DBInstance = (.*)/; 
		$names{$1}++;
	}
	close $fh;
	return \%names;
}

=head2 parse_job_properties

$foo->parse_job_properties(FILE => $file);

=cut


sub parse_job_properties {
	#3/10/2009 1:20:27 PM   Job ID = 16469
	#3/10/2009 1:20:27 PM   Creation Time = 3/10/2009 1:15:40 PM
	#3/10/2009 1:20:27 PM   Description = Running report Home
	#3/10/2009 1:20:27 PM   Job Status = WAITING_FOR_AUTOPROMPT
	#3/10/2009 1:20:27 PM   Machine Name = Server Machine: 144.226.228.180 Client Machine: 10.70.19.180
	#3/10/2009 1:20:27 PM   Owner = Doe, John
	#3/10/2009 1:20:27 PM   Priority = Low
	#3/10/2009 1:20:27 PM   Project ID = 4
	#3/10/2009 1:20:27 PM   Project Name = MicroStrategy Tutorial

	my $self = shift;
	my %parms = @_;
	@$self{keys %parms} = values %parms;
	my $fh;
	open($fh, $self->{FILE}) or croak("Unable to open " . $self->{FILE} . ": $?, $!");
	my $job_id = "";
	while (<$fh>) {
	    chomp;
    	/Job ID = / && do { 
		( undef, $job_id ) = split /= /, $_;
		$self->{JOB_PROPERTIES}->{$job_id}->{JOB_ID} = $job_id;
    	};
    /Creation Time = /
      && do { ( undef, $self->{JOB_PROPERTIES}->{$job_id}->{CREATION_TIME} ) = split /= /, $_; };
    /Description = /
      && do { ( undef, $self->{JOB_PROPERTIES}->{$job_id}->{DESCRIPTION} ) = split /= /, $_; };
    /Job Status = /
      && do { ( undef, $self->{JOB_PROPERTIES}->{$job_id}->{JOB_STATUS} ) = split /= /, $_; };
    /Machine Name = /
      && do { ( undef, $self->{JOB_PROPERTIES}->{$job_id}->{MACHINE_NAME} ) = split /= /, $_; };
    /Owner = /
      && do { ( undef, $self->{JOB_PROPERTIES}->{$job_id}->{OWNER} ) = split /= /, $_; };
    /Priority = /
      && do { ( undef, $self->{JOB_PROPERTIES}->{$job_id}->{PRIORITY} ) = split /= /, $_; };
    /Project ID = /
      && do { ( undef, $self->{JOB_PROPERTIES}->{$job_id}->{PROJECT_ID} ) = split /= /, $_; };
    /Project Name = /
      && do { ( undef, $self->{JOB_PROPERTIES}->{$job_id}->{PROJECT_NAME} ) = split /= /, $_; };
}

}
=head2 parse_list_groups

$foo->parse_list_groups(FILE => $file);

=cut

sub parse_list_groups {
	my $self = shift;
	my %parms = @_;
	@$self{keys %parms} = values %parms;
	my ($fh, @grps);
	open($fh, $self->{FILE}) or croak("Unable to open " . $self->{FILE} . ": $?, $!");
	while(my $line = <$fh>) { 
		next unless $line =~ /Group/; 
		chomp $line; 
		(undef, my $grp) = split(/\= /, $line); 
		@grps = split(/\, /, $grp);
	}
	close $fh;
	return \@grps;
}

=head2 parse_user_group_members

$foo->parse_user_group_members(FILE => $file);

LIST MEMBERS FOR USER GROUP

=cut

sub parse_user_group_members {
	my $self = shift;
	my %parms = @_;
	@$self{keys %parms} = values %parms;
	my ($fh, %names);
	open($fh, $self->{FILE}) or croak("Unable to open " . $self->{FILE} . ": $?, $!");
	while (my $line = <$fh>) {
	        next unless $line =~ /Members/;	
		chomp $line;
		(undef, my $list) = split("=", $line);
		while($list =~ /$RE{balanced}{-parens=>'()'}{-keep}/g) { 
			my $id = $`;
			my $usr = $&; 
			$list = $'; 
			$id =~ s/,//;
			$id =~ s/^\s+//; 
			$id =~ s/\s+$//;
			$usr =~ s/[()]//g;
			$names{$id} = $usr;
		}
	}
	close $fh;
	return \%names;
}

=head2 parse_project_config_properties

$foo->parse_project_config_properties(FILE => $file);

=cut

sub parse_project_config_properties {
	my $self = shift;
	my %parms = @_;
	@$self{keys %parms} = values %parms;
	my $config = {};
	my $fh;
	open($fh, $self->{FILE}) or croak("Unable to open " . $self->{FILE} . ": $?, $!");
	while(<$fh>){
    /Description = /   && do { ( undef, $config->{DESCRIPTION} ) = split( /=/, $_ ); };
    /Warehouse name = / && do { ( undef, $config->{WAREHOUSE} ) = split( /=/, $_ ); };
    /Project Status = /  && do { ( undef, $config->{STATUS} ) = split( /=/, $_ ); };
    /Show status = /    && do { ( undef, $config->{SHOWSTATUS} ) = split( /=/, $_ ); };
    /Status On Top = /  && do { ( undef, $config->{STATUSONTOP} ) = split( /=/, $_ ); };
    /HTML Document Directory = /
      && do { ( undef, $config->{DOCDIRECTORY} ) = split( /=/, $_ ); };
    /Maximum number of elements to display = /
      && do { ( undef, $config->{MAXNOATTRELEMS} ) = split( /=/, $_ ); };
    /Use linked Warehouse login for execution = /
      && do { ( undef, $config->{USEWHLOGINEXEC} ) = split( /=/, $_ ); };
    /Enable deleting of object dependencies = /
      && do { ( undef, $config->{ENABLEOBJECTDELETION} ) = split( /=/, $_ ); };
    /Maximum value of report execution time = /
      && do { ( undef, $config->{MAXREPORTEXECTIME} ) = split( /=/, $_ ); };
    /Maximum value of report result rows = /
      && do { ( undef, $config->{MAXNOREPORTRESULTROWS} ) = split( /=/, $_ ); };
    /Maximum value of element rows = /
      && do { ( undef, $config->{MAXNOELEMROWS} ) = split( /=/, $_ ); };
    /Maximum value  of Intermediate result rows = /
      && do { ( undef, $config->{MAXNOINTRESULTROWS} ) = split( /=/, $_ ); };
    /Maximum value of jobs per user account = /
      && do { ( undef, $config->{MAXJOBSUSERACCT} ) = split( /=/, $_ ); };
    /Maximum value of jobs per user session = /
      && do { ( undef, $config->{MAXJOBSUSERSESSION} ) = split( /=/, $_ ); };
    /Maximum value of executing jobs per user = /
      && do { ( undef, $config->{MAXEXECJOBSUSER} ) = split( /=/, $_ ); };
    /Maximum jobs per project = /
      && do { ( undef, $config->{MAXJOBSPROJECT} ) = split( /=/, $_ ); };
    /MaxUserSessionsProject = /
      && do { ( undef, $config->{MAXUSERSESSIONSPROJECT} ) = split( /=/, $_ ); };
    /Default Project Drill Map = /
      && do { ( undef, $config->{PROJDRILLMAP} ) = split( /=/, $_ ); };
    /Report Template = / && do { ( undef, $config->{REPORTTPL} ) = split( /=/, $_ ); };
    /Report Show Empty Template = /
      && do { ( undef, $config->{REPORTSHOWEMPTYTPL} ) = split( /=/, $_ ); };
    /Template Template = /
      && do { ( undef, $config->{TEMPLATETPL} ) = split( /=/, $_ ); };
    /Template Show Empty Template = /
      && do { ( undef, $config->{TEMPLATESHOWEMPTYTPL} ) = split( /=/, $_ ); };
    /Metric Template = / && do { ( undef, $config->{METRICTPL} ) = split( /=/, $_ ); };
    /Metric Show Empty Template = /
      && do { ( undef, $config->{METRICSHOWEMPTYTPL} ) = split( /=/, $_ ); };
    /Name = / && do { ( undef, $config->{PROJECT} ) = split( /=/, $_ ); };
    }
    return $config;
}


=head1 AUTHOR

Craig Grady, C<< <cgrady357 at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-business-intelligence-microstrategy-commandmanager-parselogs at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Business-Intelligence-MicroStrategy-CommandManager-ParseLogs>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Business::Intelligence::MicroStrategy::CommandManager::ParseLogs


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Business-Intelligence-MicroStrategy-CommandManager-ParseLogs>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Business-Intelligence-MicroStrategy-CommandManager-ParseLogs>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Business-Intelligence-MicroStrategy-CommandManager-ParseLogs>

=item * Search CPAN

L<http://search.cpan.org/dist/Business-Intelligence-MicroStrategy-CommandManager-ParseLogs>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Craig Grady, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Business::Intelligence::MicroStrategy::CommandManager::ParseLogs
