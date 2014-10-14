#!/bin/bash
######################### ANPASSEN #########################
#SSIDs mit Leerzeichen ohne Leerzeichen eintragen(Beispiel: Fritz!Box7390 statt Fritz!Box 7390)
WifiSSID=("SSID1" "SSID2")


######################### ENDE ANPASSEN #########################

TEMPSSIDArray=();
TEMPSIGNALArray=();

SSIDArray=();
SIGNALArray=();

DEBUGING="true"

function getSSIDList {
	IFS="
	"

	for line in $(sudo iwlist wlan0 scan | grep -i "ESSID" | tr -d ' ');
	do
		temp_ssid=$(echo $line | sed 's/"//g') 
		TEMPSSIDArray+=("$(echo $temp_ssid | sed -e 's/.*://g')")
	done

	for signal in `sudo iwlist wlan0 scan | grep -i "signal"`
	do
		signalStrength="$(cut -d "=" -f 3 <<< $signal)"
		TEMPSIGNALArray+=("$(echo $signalStrength | sed 's/[^0-9]*\([0-9]\+\).*/\1/')")
	done

	#Prüft ob sich das gescannte Netzwerk in der Liste der bekannten SSIDs befindet.
	index=0
	for containsSSID in "${TEMPSSIDArray[@]}";
        do
                #Iteriert das Bekannte Netzwerk Array
               	for tempSSID in "${WifiSSID[@]}" 
		do
                       #Ist das gesannte Netzwerk in dem Bekannte Netzwerk Array
                       if [ "$tempSSID" == "$containsSSID" ];
                       then
                               	echo "$tempSSID - Vorhanden"
				SSIDArray+=("$tempSSID")
				SIGNALArray+=("${TEMPSIGNALArray[$index]}")
		fi
               	done;
	((index++))
	done
}

function getStrength { 
	min=${SIGNALArray[0]}
	for i in "${SIGNALArray[@]}"
	do
    		if [[ "$i" -lt "$min" ]]; then
        		min="$i"
    		fi
	done

	for (( i = 0; i < ${#SIGNALArray[@]}; i++ )); do
   		if [ "${SIGNALArray[$i]}" = "${min}" ]; then
       			local SSIDIndex=$i;
   		fi
	done
	SSIDStrength="$(echo ${SSIDArray[$SSIDIndex]} | sed -e 's/.\"://g')"

}

#Ändert den AP zum neuen
function changeAP {
	#Fährt das WLAN Modul herunter
	sudo ifdown wlan0

	#Startet das WLAN Modul mit dem SSID Namen in der /etc/network/interfaces 
	sudo ifup wlan0=wlan0-$SSIDStrength

}

function checkAP {
	#Setzte die aktuelle verbundene SSID in die Variable nowSSID
	nowSSID="$(iwconfig wlan0 | grep -i 'ESSID' | cut -d ':' -f 2 | sed -e 's/\"//g' | tr -d ' ')"

	#Prüfe ob der stärkste AP bereits verbunden ist
	if [ "$nowSSID" != "$SSIDStrength" ]
	then
        	if [ -z "$min" ];
        	then
			echo "Es wurde kein bekannter AP in Reichweite gefunden";
			#espeak -vde "Es wurde kein Access Point in Reichweite gefunden" &
			return 0;
        	fi
		#Sollte fast nie Auftreten: Prüft ob der AP, der verbunden ist noch vorhanden ist
		if [ "$(iwconfig wlan0 | grep -i Signal | cut -d = -f 3 | sed 's/[^0-9]*\([0-9]\+\).*/\1/')" == "" ]
		then
			echo "Der verbundene AP wurde entfernt. Reconnecte mit dem nächsten in Reichweite"
			changeAP
		fi
        	#Prüfe ob der neue AP eine Stärkendifferenz von -10dBm hat.
        	if [ $(($(iwconfig wlan0 | grep -i Signal | cut -d = -f 3 | sed 's/[^0-9]*\([0-9]\+\).*/\1/')-10)) -gt $min ]
        	then
                	#Gebe die Signalstärke des neuen APs aus
                	echo "Die neue Signalstärke beträgt von $SSIDStrength: $min dBm"

                	#Falls es nicht der gleiche AP und eine Sträkendifferenz von -10dbm besteht, änder den AP auf den Stärkeren
                	echo "Der Access Point wird gewechselt..."
                	changeAP
        	fi
	#Wenn es der selbe ist
	else
        	echo "Ein Wechsel des AP ist nicht nötig"
        	echo "Aktuelle Signalstärke beträgt von $SSIDStrength: -$min dBm"
	fi
}

#Führt die Funktion getSSIDList aus.
getSSIDList

#Prüft ob die Anzahl der Elemente im Signal Array (Stärke) und SSID Array (Namen) identisch sind
if [ ${#SIGNALArray[@]} != ${#SSIDArray[@]} ] 
then
	echo "ARRAYS NOT EQUAL - Unerwarteter Fehler. Bitte nochmal versuchen!"
	exit 0
fi

#Nur Debugging. Listet die Wlan Netzte mit Signalstärke
echo "######## DEBUGING ########"
index=0
for sigStrength in "${SIGNALArray[@]}"
do
        echo -e "${SSIDArray[$index]} $sigStrength dBm"
        ((index++))
done
echo -e "######## DEBUGING ########\n"

getStrength
checkAP
