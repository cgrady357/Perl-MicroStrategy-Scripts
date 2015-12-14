package Business::Intelligence::MicroStrategy::CommandManager::NCS;
use Carp;

use warnings;
use strict;

=head1 NAME

Business::Intelligence::MicroStrategy::CommandManager::NCS - The MicroStrategy Command Manager module

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

use Business::Intelligence::MicroStrategy::CommandManager::NCS;

my $foo = Business::Intelligence::MicroStrategy::CommandManager::NCS->new();

my $fh;
my $script = "script.scp";
open( $fh, ">", $script ) or die( $?, $! );

print $fh $foo->trigger_service(
    SERVICENAME => "Service for Report Email Deliveries",
    LOCATION    => "Applications/Services for Web Deliveries/Services for project Care SLA_14 on plsw1286/Email Delivery/Report Email Delivery",
    SUBSCRIPTIONSET => ["Care SLA Event Based"], ), "\n" 
	or die( $!, $? );

$foo->set_connect(
    ODBC              => "DEV_ISERVER_5",
    USERNAME          => "joe101",
    PASSWORD          => "abc123"
);

$foo->set_inputfile($script);
$foo->set_break;
$foo->run_script;

=head1 EXPORT

Nothing exported by default.

=head1 DESCRIPTION

Use this module to create or execute MicroStrategy Narrowcast Server Command Manager scripts.  

=cut

=head1 FUNCTIONS

=head2 new

Instantiates new object.

example:
my $foo = Business::Intelligence::MicroStrategy::CommandManager::NCS->new;

=cut

sub new {
	my $class = shift;
	my $self = {};
	bless ($self, $class);
	$self->{CMDMGR_EXE} =  "C:\\PROGRA~1\\MicroStrategy\\Administrator\\Comman~1\\CMDMGR.exe";
	return $self;
}


my $q = '"';

=head2 set_cmdmgr_exe

Set location of command manager executable.

$foo->set_cmdmgr_exe("path_to_executable");

=cut

sub set_cmdmgr_exe {
	my $self = shift;
	$self->{CMDMGR_EXE} = shift;
}

=head2 get_cmdmgr_exe

Get location of command manager executable.

$foo->get_cmdmgr_exe;

=cut

sub get_cmdmgr_exe {
	my $self = shift;
	return $self->{CMDMGR_EXE};
}

=head2 set_connect

Sets the project source name, the user name, and the password

	$foo->set_connect(
	    ODBC 	      => "ODBC name", 
	    USERNAME          => "userid", 
	    PASSWORD          => "password"
	);

=cut

sub set_connect { 
	my $self = shift;
	my %parms = @_;
	for(qw(ODBC USERNAME PASSWORD)){
		if(!defined($parms{$_})) { croak("set_connect error - required parameter not defined: " , $_, "\n"); }
	}
	$self->{ODBC} = "-w " . $parms{ODBC};
	$self->{USERNAME} = "-u " . $parms{USERNAME};
	$self->{PASSWORD} = "-p " . $parms{PASSWORD};
}


=head2 set_odbc

Sets the odbc source name

$foo->set_odbc("odbc name");

=cut

sub set_odbc { 
	my $self = shift;
	$self->{ODBC} = shift;
	if(!defined($self->{ODBC})) { croak("set_odbc - required parameter not defined: ODBC\n"); }
	$self->{ODBC} = "-w " . $self->{ODBC};
}

=head2 get_odbc

Gets the odbc source name

$foo->get_odbc;

=cut

sub get_odbc { 
	my $self = shift;
	return $self->{ODBC};
}


=head2 set_system_prefix

Sets the Narrowcast Server system prefix

$foo->set_system_prefix("system prefix");

=cut

sub set_system_prefix { 
	my $self = shift;
	$self->{SYSTEM_PREFIX} = shift;
	if(!defined($self->{SYSTEM_PREFIX})) { croak("set_system_prefix - required parameter not defined: SYSTEM_PREFIX\n"); }
	$self->{SYSTEM_PREFIX} = "-s " . $self->{SYSTEM_PREFIX};
}

=head2 get_system_prefix

Gets the Narrowcast Server system prefix

$foo->get_system_prefix;

=cut

sub get_system_prefix { 
	my $self = shift;
	return $self->{SYSTEM_PREFIX};
}

=head2 set_database_name

Sets the database name

$foo->set_database_name("database name");

=cut

sub set_database_name { 
	my $self = shift;
	$self->{DATABASENAME} = shift;
	if(!defined($self->{DATABASENAME})) { croak("set_database_name - required parameter not defined: DATABASE_NAME\n"); }
	$self->{DATABASENAME} = "-d " . $self->{DATABASENAME};
}

=head2 get_database_name

Gets the database name

$foo->get_database_name;

=cut

sub get_database_name { 
	my $self = shift;
	return $self->{DATABASENAME};
}

=head2 set_user_name

sets the user name to be used in authenticating the command manager script

$foo->set_user_name("user_name");

=cut

sub set_user_name { 
	my $self = shift;
	$self->{USERNAME} = shift;
	if(!defined($self->{USERNAME})) { croak("set_user_name - required parameter not defined: USERNAME\n"); }
	$self->{USERNAME} = "-u " . $self->{USERNAME};
}

=head2 get_user_name

$foo->get_user_name;

=cut

sub get_user_name { 
	my $self = shift;
	return $self->{USERNAME};
}

=head2 set_password

Set password

Password = Provides the password for the username. 

$foo->set_password("foobar");

=cut

sub set_password { 
	my $self = shift;
	$self->{PASSWORD} = shift;
	if(!defined($self->{PASSWORD})) { croak("set_password - required parameter not defined: PASSWORD\n"); }
	$self->{PASSWORD} = "-p " . $self->{PASSWORD};
}

=head2 get_password

Get password

$foo->get_password;

=cut

sub get_password { 
	my $self = shift;
	return $self->{PASSWORD};
}

=head2 get_connect

Get ProjectSourceName, Username, Password

$foo->get_connect;

=cut

sub get_connect {
	my $self = shift;
	return $self->{ODBC}, $self->{USERNAME}, $self->{PASSWORD};
}

=head2 set_inputfile

Inputfile = Identifies the name, and the full path if necessary, of the script file (.scp) to be executed. 

If this argument is omitted, the Command Manager GUI will be launched.  Probably not the behaviour you want from your script.  In almost all cases, you should set this.

$foo->set_inputfile("input_file");

=cut

sub set_inputfile { 
	my $self = shift;
	$self->{INPUTFILE} = shift;
	if(!defined($self->{INPUTFILE})) { croak("set_inputfile - required parameter not defined: INPUTFILE\n"); }
	$self->{INPUTFILE} = "-f " . $self->{INPUTFILE};
}

=head2 get_inputfile

Inputfile = Identifies the name, and the full path if necessary, of the script file (.scp) to be executed. 

gets the input file

$foo->get_inputfile;

=cut

sub get_inputfile {
	my $self = shift;
	return $self->{INPUTFILE};
}

=head2 set_outputfile

Outputfile = Logs results, status messages, and error messages associated with the script. 

Use of the output file switch precludes use of break switch and the results file switch.

$foo->set_outputfile("output_file");

=cut

sub set_outputfile {
	my $self = shift;
	$self->{OUTPUTFILE} = shift;
	if(!defined($self->{OUTPUTFILE})) { croak("set_outputfile - required parameter not defined: OUTPUTFILE\n"); }
	$self->{OUTPUTFILE} = "-o " . $self->{OUTPUTFILE};
}

=head2 get_outputfile

Outputfile = Logs results, status messages, and error messages associated with the script. 

Use of the output file switch precludes use of break switch and the results file switch.

$foo->get_outputfile;

=cut

sub get_outputfile {
	my $self = shift;
	return $self->{OUTPUTFILE};
}

=head2 set_resultsfile

RESULTSFILE = Results log file name. Use of the results file precludes use of output file switch and the break switch.

FAILFILE = Error log file name. You may only use the fail file with results file switch.  

SUCCESSFILE = Success log file name. You may only use success file with the results file switch.

	$foo->set_resultsfile(
	    RESULTSFILE => "results file",
	    FAILFILE    => "fail file",
	    SUCCESSFILE => "success file"
	);

=cut

sub set_resultsfile {
	my $self = shift;
	my %parms = @_;
	for(qw(RESULTSFILE FAILFILE SUCCESSFILE)){
		if(!defined($parms{$_})) { croak("set_resultsfile error - required parameter not defined: " , $_, "\n"); }
	}
	$self->{RESULTSFILE} = "-or " . $parms{RESULTSFILE};
	$self->{FAILFILE} = "-of " . $parms{FAILFILE};
       	$self->{SUCCESSFILE} = "-os " . $parms{SUCCESSFILE};
}
       
=head2 map_script_output_files

$foo->map_script_output_files( SCRIPT_NAME => "script_name");

sets:
  input file = SCRIPT_NAME.scp, 
  RESULTSFILE = SCRIPT_NAME.log, 
  FAILFILE = SCRIPT_NAME.nok, 
  SUCCESSFILE = SCRIPT_NAME.ok

Opens input file for writing, and returns file handle. 

=cut

sub map_script_output_files {
	my $self = shift;
	my %parms = @_;
	@$self{keys %parms} = values %parms;
	my $script = $self->{SCRIPT_NAME} . ".scp";
	my $fh;
	open( $fh, ">", $script ) or croak("Unable to open " . $script . ": $?, $!");
	$self->set_inputfile($script);
	my ( $out, $not_ok, $ok ) = map { $self->{SCRIPT_NAME} . $_; } ( ".log", ".nok", ".ok" );
	unlink $out, $not_ok, $ok;
        $self->set_resultsfile(
           RESULTSFILE => $out,
           FAILFILE    => $not_ok,
           SUCCESSFILE => $ok
        );
	return $fh;
}

=head2 get_resultsfile

$foo->get_resultsfile;

=cut

sub get_resultsfile {
	my $self = shift;
	return $self->{RESULTSFILE}, $self->{FAILFILE}, $self->{SUCCESSFILE};
}
	
=head2 set_instructions

Displays instructions in the console and in the log files.

$foo->set_instructions;

=cut

sub set_instructions {
	my $self = shift;
	$self->{INSTRUCTIONS} = "-i ";
}

=head2 set_header

Displays header in the log files.

$foo->set_header;

=cut

sub set_header {
	my $self = shift;
	$self->{HEADER} = "-h ";
}

=head2 set_showoutput

Displays output on the console.

$foo->set_showoutput;

=cut

sub set_showoutput {
	my $self = shift;
	$self->{SHOWOUTPUT} = "-showoutput ";
}

=head2 set_stoponerror

Stops the execution on error.

$foo->set_stoponerror;

=cut

sub set_stoponerror {
	my $self = shift;
	$self->{STOPONERROR} = "-stoponerror ";
}

=head2 set_skipsyntaxcheck

Skips instruction syntax checking on a script prior to execution.

$foo->set_skipsyntaxcheck;

=cut

sub set_skipsyntaxcheck {
	my $self = shift;
	$self->{SKIPSYNTAXCHECK} = "-skipsyntaxcheck ";
}

=head2 set_error

Displays error and exit codes on the console and in the log file.

$foo->set_error;

=cut

sub set_error {
	my $self = shift;
	$self->{ERROR} = "-e ";
}

=head2 set_break

break = Separates the output into three files with the following default file names: CmdMgrSuccess.log, CmdMgrFail.log, and CmdMgrResults.log. Use of the -break switch precludes use of -o and -or, -of, and -os.

$foo->set_break;

=cut

sub set_break {
	my $self = shift;
	$self->{BREAK} = "-break ";
}


=head2 display

Displays the contents of a Business::Intelligence::MicroStrategy::Cmdmgr object. 

=cut

sub display {
	my $self = shift;
        my @keys = @_ ? @_ : sort keys %$self;
        for my $key (@keys) {
		print "\t", $key, " => ", defined($self->{$key}) ? $self->{$key} : "UNDEFINED", "\n";
        }
}


=head2 Narrowcast Server Command Manager usage

cmdmgr -w ODBC_DSN -u Login [-p Password] [-d Database] [-s System_Prefix]
[-f InputFile [-o OutputFile | -break | -or ResultsFile -of FailFile
-os SuccessFile] [-i] [-h] [-showoutput] [-stoponerror]
[-skipsyntaxcheck] [-e]]

Parameters enclosed in brackets ("[" & "]") are optional.
-w: (Narrowcast Server) ODBC Data Source Name where the
Narrowcast system resides.
-u: Username.
-p: Password.
-d: (Narrowcast Server) Database Name.
-s: (Narrowcast Server) System Prefix.
-f: Script input file, including fully qualified path.
-i: Displays instructions on the console and in the log files.
-h: Displays header in the log file.
-showoutput: Display output on the console.
-e: Displays error and exit codes on the console and in the log files.
-stoponerror: Stops the execution on error.
-skipsyntaxcheck: Skips instruction syntax checking on a script
prior to execution.
-break: Separates the output into three files with the following default
file names: CmdMgrSuccess.log, CmdMgrFail.log, and CmdMgrResults.log.
-os: Success log file name.
-of: Error log file name.
-or: Results log file name.
-o: Output log file name.
Note that the output options (-break | -o | -or -of -os)
are mutually exclusive.
If -f is not used as an argument, Command Manager will launch the GUI.
The project source name and the file names cannot have any white space
in between unless the names are between double quotes.

=cut


=head2 run_script

Executes command manager script.

$foo->run_script;

=cut

sub run_script {
        my $self = shift;
	my $args;
	for my $req ( qw(CMDMGR_EXE ODBC USERNAME PASSWORD) ) {
		if(!defined( $self->{$req} )) { croak("run_script - required parameter not set: $req\n"); }
		if($self->{$req}) { $args .= " " . $self->{$req}; } else { croak("run_script - required parameter not set: $req\n"); }
	}
	for my $option(qw(DATABASENAME SYSTEM_PREFIX INPUTFILE OUTPUTFILE BREAK RESULTSFILE FAILFILE SUCCESSFILE INSTRUCTIONS HEADER SHOWOUTPUT STOPONERROR SKIPSYNTAXCHECK ERROR)) {
		if($self->{$option}) { $args .= " " . $self->{$option}; } 
	}
	system($args)==0 or carp("run_script - running the NCS Command Manager script produced errors: ");  
};



=head2 join_objects

internal use only

=cut

sub join_objects { 
	my ($self, $key, $exp) = @_;
	my ($tmp, $cnt, $size);
	$size = @{$self->{$key}};	
	for (@{$self->{$key}}) {
		$cnt++;
		$tmp .= $q . $_ . $q; 
		if($cnt == $size) { last; }
		$tmp .= ", ";
	}
	return $exp . " " . $tmp . " ";
};


=head2 trigger_service

TRIGGER SERVICE "<service_name>" IN [FOLDER] "<location_path>" [SUBSCRIPTIONSET "<subscription_set1>" [, "<subscription_set2>" [,... "<subscription_setn>"]]];

$foo->trigger_service(
	SERVICENAME		=> "service_name",
	LOCATION		=> "location",
	SUBSCRIPTIONSET		=> [ "subscription_set1", subscription_set2", ... ] ,
);

Optional parameters: 
	SUBSCRIPTIONSET		=> [ "subscription_set1", subscription_set2", ... ] 

TRIGGER SERVICE "Service for Report Email Deliveries" IN "Applications/Services for Web Deliveries/Services for project Care SLA_14 on plsw1286/Email Delivery/Report Email Delivery" SUBSCRIPTIONSET "Care SLA Event Based";
	
$foo->trigger_service(
	SERVICENAME		=> "Service for Report Email Deliveries",
	LOCATION		=> "Applications/Services for Web Deliveries/Services for project Care SLA_14 on plsw1286/Email Delivery/Report Email Delivery",
	SUBSCRIPTIONSET		=> "Care SLA Event Based" ,
);

=cut

sub trigger_service {
	my $self = shift;
	my %parms = @_;
	my @required = qw(SERVICENAME LOCATION SUBSCRIPTIONSET);
	for(@required){
		if(!defined($parms{$_})) { croak("\ntrigger_service error - required parameter not defined: " , $_, "\n"); }
	}
	@$self{keys %parms} = values %parms;
	my $result;
	my @order = qw(SERVICENAME LOCATION SUBSCRIPTIONSET);
	my @selected;
	for(@order) { 
		exists $parms{$_} ? ( push(@selected, $_) ) : ($self->{$_} = undef);
	}
	for(@selected) {
		/SERVICENAME/ && do { $result .= "TRIGGER SERVICE " . $q . $self->{SERVICENAME} . $q . " "};
		/LOCATION/ && do { $result .= "IN FOLDER " . $q . $self->{LOCATION} . $q . " "};
		/SUBSCRIPTIONSET/ && do { $result .= $self->join_objects($_, $_) };
	}
	$result .= ";";
	return $result;
}


=head1 AUTHOR

Craig Grady, C<< <cgrady357 at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-business-intelligence-microstrategy-commandmanager at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Business-Intelligence-MicroStrategy-CommandManager-NCS>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Business::Intelligence::MicroStrategy::CommandManager::NCS


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Business-Intelligence-MicroStrategy-CommandManager-NCS>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Business-Intelligence-MicroStrategy-CommandManager-NCS>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Business-Intelligence-MicroStrategy-CommandManager-NCS>

=item * Search CPAN

L<http://search.cpan.org/dist/Business-Intelligence-MicroStrategy-CommandManager-NCS>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Craig Grady, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Business::Intelligence::MicroStrategy::CommandManager::NCS
