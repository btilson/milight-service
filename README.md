# milight-service

Perl application and web service to control Milight/LimitlessLED bulbs

Web service script (lights.pl) accepts the URI parameters:

	name (required) - user generated name of zone at particular host
	state - 'on', 'off', 'toggle'
	brightness - '1-10' for Dual White, '1-26' for RGBW
	interval - seconds, used inconjuntion with brightness for slow trasition eg. 0.2 (200ms)
	colour - 'red' 'green' 'blue' etc and hex values (currently construction in progress)
	hue - '1-10', white cooler to warmer
	notification - 'true' will make light flash on/off twice (future will accept 'alarm' for example which could flash the light red)
	enforcetime - 'true' will not turn lights on if 7PM-7AM (in progress pull weather RSS and allow daytime lights if raining/cloudy)
	delay - seconds (used to delay the request by x seconds)

Application (light_control.pl) accepts the above commands from the CLI
