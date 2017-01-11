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

while [ true ] ;do
  rm -f /$TMPDIR/linefile
  /usr/local/bin/rabbitmq-dump-queue -uri "amqp://$USER:$PASS@$RABBITMQHOST/$VHOST" -max-messages=$MESSAGES -output-dir $TMPDIR -queue=$QUEUE -ack=true 2>&1>/dev/null
  for file in `seq -w $MESSAGES`; do
    if [ -f /$TMPDIR/msg-00$file ]; then
      cat $TMPDIR/msg-00$file >> $TMPDIR/linefile
      echo >> $TMPDIR/linefile
    fi
  done
  if [ -f $TMPDIR/linefile ]; then
    echo "Submitting `wc -l $TMPDIR/linefile `"
    rm -r $TMPDIR/msg-*
    curl -q -i -XPOST "http://$INFLUXDB_HOST:8086/write?db=$INFLUXDB_DB" --data-binary @$TMPDIR/linefile
  else
    echo "No messages, sleeping"
    sleep 10
  fi
done
