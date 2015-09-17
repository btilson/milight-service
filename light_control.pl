#! /usr/bin/perl -w

## Version 0.4 (9/9/15)
#
# Edit SQLite DB file path in get_dbsource subroutine

use strict;

use Getopt::Mixed;
use DBI;
use IO::Socket;

my ($optLight, $optState, $optDelay, $optBrightness, $optTransInterval, $optColour, $optHue, $optNotification, $optEnforceTime);

Getopt::Mixed::init( 'l=s s=s d=i b=i t=s c=i h=i n=i e=s light>l state>s delay>d brightness>b interval>t colour>c hue>h notification>n enforcetime>e');

while( my( $option, $value, $pretty ) = Getopt::Mixed::nextOption() ) {
	OPTION: {
      	$option eq 'l' and do {
        	$optLight = $value; 
        	last OPTION;
      	};
		$option eq 's' and do {
            $optState = $value if $value;
			$optState = lc $optState;
			$optState = 0 if $optState eq 'off';
			$optState = 1 if $optState eq 'on';
			$optState = 9 if $optState eq 'toggle';
            last OPTION;
		};
		$option eq 'd' and do {
            $optDelay = $value if $value;
            last OPTION;
		};
		$option eq 'b' and do {
            $optBrightness = $value if $value;
            last OPTION;
		};
		$option eq 't' and do {
            $optTransInterval = $value if $value;
            last OPTION;
                };
		$option eq 'c' and do {
            $optColour = $value if $value;
            last OPTION;
		};
		$option eq 'h' and do {
            $optHue = $value if $value;
            last OPTION;
		};
		$option eq 'n' and do {
            $optNotification = $value if $value;
            last OPTION;
		};
		$option eq 'e' and do {
            $optEnforceTime = $value if $value;
            last OPTION;
		};
	}
}
Getopt::Mixed::cleanup();

die "No light specified via -l or --light.\n" unless $optLight;

checkTime() if $optEnforceTime;  ## If enforce time flag parsed, check is 'night time' before allowing lights

my %light = getLightDB($optLight);

if ( defined $optNotification ) {
		sendNotification($optNotification,$light{zone},$light{type},$light{host},$light{state},$light{brightness},$light{colour},$light{hue});
}

if ( defined $optState && $optState != $light{state} ) {
		my $newState = changeLightState($optState,$optDelay,$light{zone},$light{type},$light{host},$light{state});
		changeLightStateDB($light{id},$newState);
}

if ( defined $optBrightness && $light{state} != 0 ) {
		my $newBrightness = changeLightBrightness($optBrightness,$light{zone},$light{type},$light{host},$light{brightness},$optTransInterval);
		changeLightBrightnessDB($light{id},$newBrightness);
}

sub changeLightState {

	my $optState = shift;
	my $optDelay = shift;
	my $zone = shift;
	my $type = shift;
	my $host = shift;
	my $state = shift;
	
	my ($offHex, $onHex);
	
	sleep $optDelay if $optDelay;
	
	my $socks = IO::Socket::INET->new(
		Proto    => 'udp',
		PeerPort => 8899,
		PeerAddr => $host,
	) or die "It didn't work. $! \n";
	
	if ( $optState == 9 ) {
		## State option is 'toggle', make state opposite of current state
		$optState = 0 if $state == 1;
		$optState = 1 if $state == 0;
	}
	
	if ( $optState == 0 ) {
		## Turn off lights
		my $offHex = getHexOnOffValue($zone,$type,0);
		
		$socks->send($offHex) or die "Nope, can't send that. $! \n";
		select(undef, undef, undef, 0.10); ## Delay 100ms
		$socks->send($offHex) or die "Nope, can't send that. $! \n";
		select(undef, undef, undef, 0.10); ## Delay 100ms
        $socks->send($offHex) or die "Nope, can't send that. $! \n";
		
		$state = $optState
	}
	elsif ( $optState == 1 ) {
		## Turn on light UDP call
		my $onHex = getHexOnOffValue($zone,$type,1);
		
		$socks->send($onHex) or die "Nope, can't send that. $! \n";
		select(undef, undef, undef, 0.10); ## Delay 100ms
		$socks->send($onHex) or die "Nope, can't send that. $! \n";
		select(undef, undef, undef, 0.10); ## Delay 100ms
        $socks->send($onHex) or die "Nope, can't send that. $! \n";

		$state = $optState
	}
	return $state;
}

sub changeLightBrightness {
	
	my $optBrightness = shift;
	my $zone = shift;
	my $type = shift;
	my $host = shift;
	my $brightness = shift;
	my $optTransInterval = shift;
	
	my ($brightenHex, $dimHex);
	my $interval;

	my $onHex = getHexOnOffValue($zone,$type,1);

	if ( $optTransInterval ) {
		$interval = $optTransInterval;
	}
	else {
		$interval = 0.10;
	}
	
	my $socks = IO::Socket::INET->new(
		Proto    => 'udp',
		PeerPort => 8899,
		PeerAddr => $host,
	) or die "It didn't work. $! \n";
	
	if ( $type eq 'DW' ) {
		$optBrightness = "10" if $optBrightness > 10;
		if ( $optBrightness > $brightness ) {
			## Increase brightness
			$brightenHex = "\x3C\x00\x55";
			my $count = $optBrightness - $brightness;
			$socks->send($onHex) or die "Nope, can't send that. $! \n";
			select(undef, undef, undef, 0.10); ## Delay 100ms
			for (my $i=0; $i <= $count; $i++) {
				$socks->send($brightenHex) or die "Nope, can't send that. $! \n";
				select(undef, undef, undef, $interval); ## Delay predefined interval
			}
		}
		elsif ( $optBrightness < $brightness ) {
			## Decrease brightness
			$dimHex = "\x34\x00\x55";
			my $count = $brightness - $optBrightness;
			$socks->send($onHex) or die "Nope, can't send that. $! \n";
			select(undef, undef, undef, 0.10); ## Delay 100ms
			for (my $i=0; $i <= $count; $i++) {
				$socks->send($dimHex) or die "Nope, can't send that. $! \n";
				select(undef, undef, undef, $interval); ## Delay predefined interval
			}
		}
		return $optBrightness;
	}
	elsif ( $type eq 'RGBW' ) {
		$optBrightness = "25" if $optBrightness > 25;
		if ( $optBrightness > $brightness ) {
			$brightness = $brightness + 1;
			my %brightnessHexValues = getBrightnessHexValuesDB();
			$socks->send($onHex) or die "Nope, can't send that. $! \n";
			select(undef, undef, undef, 0.10); ## Delay 100ms
			if ( defined $optTransInterval ) {
				## Transition interval specified, step through brightness intervals
				for (my $i=$brightness; $i <= $optBrightness; $i++) {
					my $hexValue = pack "H*",$brightnessHexValues{$i};
					$socks->send($hexValue) or die "Nope, can't send that. $! \n";
					select(undef, undef, undef, $interval); ## Delay predefined interval
				}
			}
			else {
				## No transition, go straight to new brightness
				my $hexValue = $brightnessHexValues{$optBrightness};
				$socks->send($hexValue) or die "Nope, can't send that. $! \n";
				select(undef, undef, undef, $interval); ## Delay predefined interval
				$socks->send($hexValue) or die "Nope, can't send that. $! \n";
			}
		}
		elsif ( $optBrightness < $brightness ) {
			$brightness = $brightness - 1;
			my %brightnessHexValues = getBrightnessHexValuesDB();
			$socks->send($onHex) or die "Nope, can't send that. $! \n";
			select(undef, undef, undef, 0.10); ## Delay 100ms
			if ( defined $optTransInterval ) {
				## Transition interval specified, step through brightness intervals
				for (my $i=$brightness; $i >= $optBrightness; $i--) {
					my $hexValue = pack "H*",$brightnessHexValues{$i};
					$socks->send($hexValue) or die "Nope, can't send that. $! \n";
					select(undef, undef, undef, $interval); ## Delay predefined interval
				}
			}
			else {
				## No transition, go straight to new brightness
				my $hexValue = $brightnessHexValues{$optBrightness};
				$socks->send($hexValue) or die "Nope, can't send that. $! \n";
				select(undef, undef, undef, $interval); ## Delay predefined interval
				$socks->send($hexValue) or die "Nope, can't send that. $! \n";
			}
		}
		return $optBrightness;
	}
}

sub sendNotification {

	my $optNotification = shift;
	my $zone = shift;
	my $type = shift;
	my $host = shift;
	my $state = shift;
	my $brightness = shift;
	my $colour = shift;
	my $hue = shift;
	
	my $offHex = getHexOnOffValue($zone,$type,0);
	my $onHex = getHexOnOffValue($zone,$type,1);
	
	my $socks = IO::Socket::INET->new(
		Proto    => 'udp',
		PeerPort => 8899,
		PeerAddr => $host,
	) or die "It didn't work. $! \n";
	
	## Flash twice notification
	$socks->send($onHex) if $state == 0;
	select(undef, undef, undef, 0.10); ## Delay 100ms
	$socks->send($onHex) if $state == 0;
	select(undef, undef, undef, 0.10); ## Delay 100ms
	$socks->send($onHex);
	select(undef, undef, undef, 0.20); ## Delay 200ms
	$socks->send($offHex);
	select(undef, undef, undef, 0.20); ## Delay 200ms
	$socks->send($onHex);
	select(undef, undef, undef, 0.20); ## Delay 200ms
	$socks->send($offHex);
	select(undef, undef, undef, 0.20); ## Delay 200ms
	$socks->send($onHex) if $state == 1;
	select(undef, undef, undef, 0.10); ## Delay 100ms
	$socks->send($offHex) if $state == 0;	
	
}

sub getHexOnOffValue {
	
	my $zone = shift;
	my $type = shift;
	my $state = shift;
	
	my $hexValue = "error";
	
	if ( $type eq 'DW' && $state == 0 ) {
		## Dual White OFF HEX Values
		$hexValue = "\x3B\x00\x55" if $zone == 1;
		$hexValue = "\x33\x00\x55" if $zone == 2;
		$hexValue = "\x3A\x00\x55" if $zone == 3;
		$hexValue = "\x36\x00\x55" if $zone == 4;
	}
	elsif ( $type eq 'DW' && $state == 1 ) {
		## Dual White ON HEX Values
		$hexValue = "\x38\x00\x55" if $zone == 1;
		$hexValue = "\x3D\x00\x55" if $zone == 2;
		$hexValue = "\x37\x00\x55" if $zone == 3;
		$hexValue = "\x32\x00\x55" if $zone == 4;
	}
	elsif ( $type eq 'RGBW' && $state == 0 ) {
		## RGBW OFF HEX Values
		$hexValue = "\x46\x00\x55" if $zone == 1;
		$hexValue = "\x48\x00\x55" if $zone == 2;
		$hexValue = "\x4A\x00\x55" if $zone == 3;
		$hexValue = "\x4C\x00\x55" if $zone == 4;
	}
	elsif ( $type eq 'RGBW' && $state == 1 ) {
		## RGBW ON HEX Values
		$hexValue = "\x45\x00\x55" if $zone == 1;
		$hexValue = "\x47\x00\x55" if $zone == 2;
		$hexValue = "\x49\x00\x55" if $zone == 3;
		$hexValue = "\x4B\x00\x55" if $zone == 4;
	}

	return $hexValue;
}

sub checkTime {
	use Time::localtime;
	my $hour = localtime->hour();
	if ( $hour <= 19 && $hour >= 7 ) {
		## Is 'daytime' between 7AM and 7PM, do not allow lights and exit
		exit;
	}
}

sub getLightDB {

	$optLight = shift;

	my %light;

	my $ds = get_datasource();
	my $dbh = DBI->connect($ds) || die "DBI::errstr";
	
	my ($id, $name, $zone, $type, $host, $state, $brightness, $colour, $hue);
	my $query = $dbh->prepare("select ID, NAME, ZONE, TYPE, HOST, STATE, BRIGHTNESS, COLOUR, HUE from LIGHTS where NAME = '$optLight'") || die "DBI::errstr";
	$query->execute;
	$query->bind_columns(\$id,\$name,\$zone,\$type,\$host,\$state,\$brightness,\$colour,\$hue);
	
	while ($query->fetchrow_arrayref()) {
		$light{"id"}=$id;
		$light{"name"}=$name;
		$light{"zone"}=$zone;
		$light{"type"}=$type;
		$light{"host"}=$host;
		$light{"state"}=$state;
		$light{"brightness"}=$brightness;
		$light{"colour"}=$colour;
		$light{"hue"}=$hue;
	}
	
	$query->finish();
	
	return %light;
}

sub getBrightnessHexValuesDB {
	
	my ($key, $value);
	my %brightnessHexValues;
	
	my $ds = get_datasource();
	my $dbh = DBI->connect($ds) || die "DBI::errstr";
	
	my $query = $dbh->prepare("select key, HEX_value from RGBW_BRIGHTNESS_HEX_VALUES order by key") || die "DBI::errstr";
	$query->execute();
	$query->bind_columns(\$key,\$value);

	while ($query->fetch) {
                $brightnessHexValues{"$key"}=$value;
    }
    
	$query->finish();
	
	return %brightnessHexValues;
}

sub changeLightStateDB {

	my $id = shift;
	my $state = shift;
	
	my $ds = get_datasource();
	my $dbh = DBI->connect($ds) || die "DBI::errstr";
	
	my $query = $dbh->prepare("update LIGHTS set STATE = '$state' where ID = '$id'") || die "DBI::errstr";
	$query->execute();
	
	$query->finish();

}

sub changeLightBrightnessDB {

	my $id = shift;
	my $brightness = shift;
	
	my $ds = get_datasource();
	my $dbh = DBI->connect($ds) || die "DBI::errstr";
	
	my $query = $dbh->prepare("update LIGHTS set BRIGHTNESS = '$brightness' where ID = '$id'") || die "DBI::errstr";
	$query->execute();
	
	$query->finish();

}

sub get_datasource {

    my $db_location = "/usr/local/bin/lights/lights.db";
    my $ds = "DBI:SQLite:dbname=$db_location";

    return $ds;
}

