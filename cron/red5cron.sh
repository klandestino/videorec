#!/bin/sh

# --- CONFIGURATION ---

# Remember! Trailing slashes!
RED5MISSIONCONTROL='http://172.17.20.2:81/'
HTTPPREFIX='http://testserver/asdfasdfasdf/asdfasdf/'
RTMPPREFIX='rtmp://rtmpserver/'

# --- IF WE ARE ONLINE, THEN NOTIFY THE RED 5 MISSION CONTROL ---

if [ "`netstat -n -l | grep 1935 | grep LISTEN`" != "" ]; then
	curl --data-urlencode "httpprefix=$HTTPPREFIX" --data-urlencode "rtmpprefix=$RTMPPREFIX" "$RED5MISSIONCONTROL""servernotification/"
	echo hej
fi

# --- DELETE ALL DATA FROM /tmp/red5data THAT IS OLDER THAN ONE HOUR ---

find /tmp/red5data -type f -mmin +60 -exec rm -- {} \;

