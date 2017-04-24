#!/bin/sh

HOSTTOPING=8.8.8.8
PINGSIZE=10
PINGTIMEOUT=30
PINGCOUNT=3
SERIALTTY=/dev/ttyUSB0
DONGLEMISSING=0

##run forever
logger "$0 starting"
while :
do
  if [ -c $SERIALTTY ]
  then
    DONGLEMISSING=0
    #TODO: check if connected
    #connect

    PINGRESULT=`ping -w $PINGTIMEOUT -c $PINGCOUNT -s $PINGSIZE $HOSTTOPING | sed -e 's/, /\n/g' | grep "packet loss" | cut -f 1 -d "%"`
    echo "Pingresult $PINGRESULT% loss"
    #TODO: check signal quality
    #TODO: check connection type

    #disconnect if all packets where lost
    if [ -z "$PINGRESULT" ] || [ $PINGRESULT -eq 100 ]
    then
      logger "WARNING: unable to ping google, reconnecting"
      ##apperently sometimes the tty goes down, break out and wait
      ##for it to comeback
      if [ ! -c $SERIALTTY ]
      then
         continue
      fi
	
      ##take down interface and reconnect
      ifdown wwan0
      echo -e "AT^NDISDUP=1,0,\"bredband.tre.se\"\r" > $SERIALTTY
      sleep 1
      echo -e "AT^NDISDUP=1,1,\"bredband.tre.se\"\r" > $SERIALTTY
      ifup wwan0
      ADDR=`ifconfig wwan0 | grep addr`
      if [ -z "$ADDR" ]
      then
        logger "WARNING: no address received"
      fi
##      exit 1
    else
      #all ok
      sleep 5
    fi
  else 
    if [ $DONGLEMISSING -eq 0 ]
    then
      logger "no 3g dongle found!"
      DONGLEMISSING=1
    fi
    sleep 5
  fi
done
