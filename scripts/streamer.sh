#!/bin/bash
# Title         : streamer.sh
# Author        : Matthew Steggink
# Usage         : GPLv2
# Source        : https://github.com/msteggink/rabbitmq-to-influxdb
# Description   : This script reads out a RabbitMQ queue and inserts the content into InfluxDB.
#

TMPDIR=/tmp
MESSAGES=16
RABBITMQHOST="rabbit.example.com"
VHOST="%2Finfluxdb"
QUEUE="influxq"
USER="rabbit"
PASS="rabbit"
INFLUXDB_HOST="influxdb.example.com"
INFLUXDB_DB="telegraf"
LOCKFILE=/var/run/streamer

function ctrl_c() {
  rm -f $LOCKFILE
  exit 0
}


if [ -f $LOCKFILE ]; then
  echo "Lockfile present"
  echo "Please check why. Submit the last metrics and remove the lockfile $LOCKFILE"
  echo "curl -s -q -i -XPOST \"http://$INFLUXDB_HOST:8086/write?db=$INFLUXDB_DB\" --data-binary @$TMPDIR/linefile"
  exit 1
fi

if [ -f $TMPDIR/linefile ]; then
  echo "Possible unsubmitted metrics found."
  echo "curl -s -q -i -XPOST \"http://$INFLUXDB_HOST:8086/write?db=$INFLUXDB_DB\" --data-binary @$TMPDIR/linefile"
  exit 1
fi

touch /var/run/streamer
while [ true ] ;do
  rm -f /$TMPDIR/linefile
  /usr/local/bin/rabbitmq-dump-queue -uri "amqp://$USER:$PASS@$RABBITMQHOST/$VHOST" -max-messages=$MESSAGES -output-dir $TMPDIR -queue=$QUEUE --ack=true 2>&1 > /dev/null
  for file in `seq -w 0 $MESSAGES`; do
    if [ -f /$TMPDIR/msg-00$file ]; then
      cat $TMPDIR/msg-00$file >> $TMPDIR/linefile
      echo >> $TMPDIR/linefile
    fi
  done
  if [ -f $TMPDIR/linefile ]; then
    echo -n "Submitting `wc -l $TMPDIR/linefile ` lines... "
    rm -r $TMPDIR/msg-*
    RT=`curl -s -w "%{http_code}" -q -i -XPOST "http://$INFLUXDB_HOST:8086/write?db=$INFLUXDB_DB" --data-binary @$TMPDIR/linefile -o /dev/null`
    if [ $RT -ne 204 ]; then
      echo "Unexpected response, aborting."
      exit 1
    else
      rm -f $TMPDIR/linefile
      echo " done"
    fi
  else
    echo "No messages, sleeping"
    sleep 30
  fi
done
