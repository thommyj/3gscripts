#!/bin/sh
set -e
set -x
HOSTTOPING=8.8.8.8
PINGSIZE=10
PINGTIMEOUT=30
PINGCOUNT=3
SERIALTTY="none"
LOGTAG="$0"

##run forever
logger -t $LOGTAG -s "$0 starting"
loop=0
fail=0
while :
do
	if [ ! -z "$SERIALTTY" -a -c $SERIALTTY ]
	then
		loop=$((loop + 1))
		echo -n "loop $loop, failed $fail"
		PINGRESULT=`ping -w $PINGTIMEOUT -c $PINGCOUNT -s $PINGSIZE $HOSTTOPING | sed -e 's/, /\n/g' | grep "packet loss" | cut -f 1 -d "%"` 2>/dev/null
		echo ", pingresult $PINGRESULT% loss"

		#disconnect if all packets where lost
		if [ -z "$PINGRESULT" ] || [ $PINGRESULT -eq 100 ]
		then
			logger -t $LOGTAG -s "WARNING: unable to ping google, reconnecting"
			fail=$((fail + 1))
			ADDR=
			while [ -z "$ADDR" ]
			do
				##take down interface and reconnect
				ifdown wwan0
				echo -e "AT^NDISDUP=1,0,\"bredband.tre.se\"\r" >&3 || continue
				sleep 1
				echo -e "AT^NDISDUP=1,1,\"bredband.tre.se\"\r" >&3 || continue
				ifup wwan0
				ADDR=`ifconfig wwan0 | grep "inet addr"`
				logger -t $LOGTAG -s "received addr=$ADDR"
				sleep 2
			done
		else
			#all ok
			sleep 5
		fi
	else 
		sleep 1
		exec 3>&-
		SERIALTTY=`dmesg | grep -E "GSM modem.*attached" | tail -n 1 | sed -e 's/^.* attached to //g'`
		SERIALTTY="/dev/${SERIALTTY}"
		[ ! -z "$SERIALTTY" -a -c $SERIALTTY ] && exec 3<> $SERIALTTY && continue
		logger -t $LOGTAG -s "no 3g dongle found!"
		sleep 15
	fi
done
