#!/bin/bash

urlprefix="$1"
checkinterval=60




tmpdir="/tmp/$USER.checkwebservice"

if [ ! "$urlprefix" ]; then
	echo "usage: $0 <url-prefix> (e.g. http://lcas.lincoln.ac.uk/linda)" >&2
	return 1
fi

mkdir -p "$tmpdir"


function check_mjpeg {
	mf="$tmpdir/mjpeg.jpg"
	rm -f "$mf"
	wget -t 2 --timeout=10 -O "$mf" "$urlprefix/video/snapshot?topic=/image_blurrer/output_video" &
	wget_pid=$!
	sleep 10
	kill $wget_pid
	mfs=`du /tmp/marc.checkwebservice/mjpeg.jpg | cut -f1`
	if [ "$mfs" -gt 10 ]; then
		return 0
	else
		return 1
	fi
}

function check_service {
if rostopic info /webthrottle/image | grep -A2 Publishers | grep -q web_mux; then
	echo "ROS topic is ok." >&2
else
	echo "ROS topic not publishing." >&2
	return 1
fi

if wget -t 3 --timeout=5 -O "$tmpdir/rosws.txt" "$urlprefix/rosws"  2>&1 | grep  "Upgrade Required"; then
	echo "ROSWS is ok." >&2
else
	echo "querying rosws failed" >&2
	return 1
fi

if check_mjpeg; then
	echo "mjpeg_server is ok." >&2
else
	echo "mjpeg_server doesn't respond" >&2
	return 1
fi
return 0
}


while true; do
	if check_service; then
		echo "everything seems working fine" >&2
	else
		echo "need to restart webtools." >&2
		if [ "$rl_pid" ]; then
			kill $rl_pid
			sleep 10
			kill -9 $rl_pid
		fi
		roslaunch strands_webtools webtools_safe.launch &
		rl_pid=$!
	fi
	sleep $checkinterval
done

