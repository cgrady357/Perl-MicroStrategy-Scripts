#!/usr/bin/perl
# by Craig Grady
# Created 1/25/2014

use strict;
use warnings;
use File::Copy;
use File::Basename;

my $msi_deploy = "/development1/0ap/0ap-development1-msiweb/deploy/";
my $msi_install = "/development1/0ap/msiweb/MicroStrategy/install/";
my $rm = "rm -rf *";
my $cp = "/bin/cp";
my $jar =  "/tools/ews/jdk/jdk1.6.0_23/bin/jar";
my $google_map = "/development1/0ap/msiweb/MicroStrategy/install/GISConnectors/GoogleMap/ConnectorForGoogleMap/ConnectorForGoogleMap";
my $google_config = "/development2/0ap/software/googleConfig.xml";
my $google_plugin = "/plugins/ConnectorForGoogleMap/WEB-INF/xml/config/google/";
my $esri = "/development2/0ap/software/em4mstr";
my $project_sources = "/development2/0ap/software/projectsources.xml";
my %apps = ("MSIReporting" => "WebUniversal/MicroStrategy.war",
            "MSIFinance"  =>  "WebUniversal/MicroStrategy.war", 
			"MicroStrategy" => "WebUniversal/MicroStrategy.war",
			"MicroStrategyWS" => "WebServicesJ2EE/MicroStrategyWS.war",
			"CertificateServer" => "Mobile/MobileServer/CertificateServer.war",
			"MicroStrategyMobile" => "Mobile/MobileServer/MicroStrategyMobile.war"
			);

for my $app (keys %apps) { 
my $path = $msi_deploy . $app; 
print "Changing directory to $path\n";
chdir $path or die "Can't cd to $path: $!\n";
print "Recursively removing all files and subdirectories $rm\n";
my @args = ($rm);
system(@args) == 0
        or die "system @args failed: $?";
my $war = $msi_install . $apps{$app};		
print "War file: $war\n";
my $base_name = fileparse($war,".war");
my $new_war = $path . "/" . $base_name . ".war"; 
print "New war file: $new_war\n";
@args = ($cp, "-R", $war, $new_war);
print "Copying ", join(" ", @args), "\n";
system(@args) == 0
        or die "system @args failed: $?";
@args = ($jar, "-xvf", $new_war);
print "Extracting jar file: ", join(" ", @args), "\n";
system(@args) == 0
        or die "system @args failed: $?";
@args = ("rm", "-f", $new_war);
print "Removing war file: ", join(" ", @args), "\n";
system(@args) == 0
        or die "system @args failed: $?";
if ($apps{$app} eq "WebUniversal/MicroStrategy.war") {
my $plugin_dir = $path . "/plugins";
@args = ($cp, "-R", $google_map, $plugin_dir);
print "Copying ", join(" ", @args), "\n";
system(@args) == 0
        or die "system @args failed: $?";
my $new_google_config = $path . $google_plugin;
@args = ($cp, $google_config,  $new_google_config);
print "Copying ", join(" ", @args), "\n";
system(@args) == 0
        or die "system @args failed: $?";
@args = ($cp, "-R", $esri, $plugin_dir);
print "Copying ", join(" ", @args), "\n";
system(@args) == 0
        or die "system @args failed: $?";
}
if ($apps{$app} eq "WebServicesJ2EE/MicroStrategyWS.war") {
@args = ($cp, $project_sources, $path);
print "Copying ", join(" ", @args), "\n";
system(@args) == 0
        or die "system @args failed: $?";
}
@args = ('chmod -R 777 *');
print "Granting open access: ", join(" ", @args), "\n";
system(@args) == 0 or die "system @args failed: $?";
}
