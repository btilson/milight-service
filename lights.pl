#!/usr/bin/perl -w

## Web Service CGI Application - Version 0.4 (9/9/15)
##
## Edit API Key and system command string below

use CGI qw(:standard);
use strict;

my $query = new CGI;
my $api = $query->param('api');
## ENTER A API KEY BELOW
my $apiKey = '<GENERATE KEY>';

$ENV{"PATH"} = "/usr/bin";

print $query->header("text/plain");

if ( $api eq $apiKey && defined $query->param('name') ) {
	my $argString;
	
	$argString = "-l " . $query->param('name') if $query->param('name');
	$argString .= " -s " . $query->param('state') if $query->param('state');
	$argString .= " -d " . $query->param('delay') if $query->param('delay');
	$argString .= " -b " . $query->param('brightness') if $query->param('brightness');
	$argString .= " -t " . $query->param('interval') if $query->param('interval');
	$argString .= " -c " . $query->param('colour') if $query->param('colour');
	$argString .= " -h " . $query->param('hue') if $query->param('hue');
	$argString .= " -n " . $query->param('notification') if $query->param('notification');
	$argString .= " -e " . $query->param('enforcetime') if $query->param('enforcetime');

	print "API Key Valid, performing light commands\n";
	## EDIT PATHS IN SYSTEM CALL BELOW
	system("/usr/bin/perl /usr/local/bin/lights/light_control.pl $argString >/dev/null &");
}
elsif ( $api eq $apiKey && ! defined $query->param('name') ) {
	print "LIGHTS WEBSERVICE PARAMETERS\n\n";
	print "name (required) - user generated name of zone at particular host\n";
	print "state - 'on', 'off', 'toggle'\n";
	print "brightness - '1-10' for Dual White, '1-26' for RGBW\n";
	print "interval - seconds, used inconjuntion with brightness for slow trasition eg. 0.2 (200ms)\n";
	print "colour - 'red' 'green' 'blue' etc and hex values (currently construction in progress)\n";
	print "hue - '1-10', white cooler to warmer\n";
	print "notification - 'true' will make light flash on/off twice (future will accept 'alarm' for example which could flash the light red)\n";
	print "enforcetime - 'true' will not turn lights on if 7PM-7AM (in progress pull weather RSS and allow daytime lights if raining/cloudy)\n";
	print "delay - seconds (used to delay the request by x seconds)\n";
}
elsif ( $api ne $apiKey ) {
	print "API Key Invalid\n";
}
