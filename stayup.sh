#!/bin/sh
#set -e
set -x

PING_HOST=8.8.8.8
PING_SIZE=10
PING_TIMEOUT=10
PING_COUNT=3
PING_WAIT=2
SERIALTTY="none"
LOGTAG="$0"
MAX_RECONNECT_TRIES=3

reconnect () {
	##take down interface and reconnect
	ifdown wwan0
	echo -e "AT^NDISDUP=1,0,\"bredband.tre.se\"\r" >&3 || return
	sleep 1
	echo -e "AT^NDISDUP=1,1,\"bredband.tre.se\"\r" >&3 || return
	ifup wwan0 || return
	ADDR=`ifconfig wwan0 | grep "inet addr"`
	logger -t $LOGTAG -s "received addr=$ADDR"
	sleep 2
}

##run forever
logger -t $LOGTAG -s "$0 starting"
loop=0
fail=0
reset=0
reconnect_attemps=0

while :
do
	if [ ! -z "$SERIALTTY" -a -c $SERIALTTY -a true >&3 ]
	then
		loop=$((loop + 1))
		echo -n "loop $loop : failed $fail : reset $reset"

		ADDR=`ifconfig wwan0 | grep "inet addr"`
		if [ ! -z "$ADDR" ]
		then
			reconnect_attemps=0
			PINGRESULT=$(ping -w $PING_TIMEOUT -c $PING_COUNT -s $PING_SIZE -i $PING_WAIT $PING_HOST)
			echo "(ping return $?)"
			PINGRESULT=$(echo $PINGRESULT | sed -e 's/, /\n/g' | grep "packet loss" | cut -f 1 -d "%") 2>/dev/null
			echo ", pingresult $PINGRESULT% loss"

			#disconnect if all packets where lost
			if [ -z "$PINGRESULT" ] || [ $PINGRESULT -eq 100 ]
			then
				logger -t $LOGTAG -s "WARNING: unable to ping google, reconnecting"
				fail=$((fail + 1))
				ifdown wwan0
			else
				#all ok
				sleep 10
			fi
		elif [ $reconnect_attemps -lt $MAX_RECONNECT_TRIES ]
		then
			reconnect
			reconnect_attemps=$((reconnect_attemps + 1))
		else
			reset=$((reset + 1))
			reconnect_attemps=0
			echo -e "AT^RESET\r" >&3 || continue
		fi
	else 
		sleep 1
		exec 3>&-
		SERIALTTY=`dmesg | grep -E "GSM modem.*attached" | tail -n 1 | sed -e 's/^.* attached to //g'`
		SERIALTTY="/dev/${SERIALTTY}"
		[ ! -z "$SERIALTTY" -a -c $SERIALTTY ] && exec 3<> $SERIALTTY \
			&& echo -e "AT^SYSCFGEX=\"02\",3fffffff,1,2,7fffffffffffffff,\"\",\"\"\r" >&3 \
			&& continue
		SERIALTTY=
                logger -t $LOGTAG -s "no 3g dongle found!"
		sleep 15
	fi
done
