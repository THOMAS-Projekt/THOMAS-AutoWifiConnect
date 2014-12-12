#!/bin/bash
#$1
if [ "$1" == "-h" ]
then
	echo -e "Hilfe: \nSetup: setup \nIn Interfaces einfügen: SSID, PW, Address, Netmask, Gateway"
	exit;
fi

if [ "$1" == "setup" ]
then
	$(touch interfaces);
	echo -e "auto lo \niface lo inet loopback \n\nauto eth0 \niface eth0 inet dhcp\n\n" > interfaces
	exit;
fi
IFS=$'\n'

for f in $(wpa_passphrase $1 $2 | sed -n -e 's/^.*psk=//p');
do
passphrase=$f;
done
#Ausgabe in Datei
echo 	"iface wlan0-"$1" inet static
	address"	$3"
	netmask" 	$4"
	gateway"	$5"
	wpa-ssid"	$1"
	wpa-psk"	$passphrase >> interfaces
