# Using RabbitMQ as buffer for InfluxDB

## RabbitMQ

First, set up RabbitMQ. Best is to use configuration management tools such as [Ansible]( http://docs.ansible.com/ansible/list_of_messaging_modules.html) or [Puppet](https://github.com/puppetlabs/puppetlabs-rabbitmq).

Please check the documentation for setting up everything in HA mode.


Here are the manual steps:

Add the vhost:
```
# /usr/sbin/rabbitmqctl -q -n rabbit add_vhost /influxdb
```
Add the user
```
# /usr/sbin/rabbitmqctl -q -n rabbit add_user rabbit rabbit
```
Set permissions for the user (rabbit) and the admin (guest).
```
# /usr/sbin/rabbitmqctl -q -n rabbit set_permissions -p /influxdb rabbit ".*" ".*" ".*"
# /usr/sbin/rabbitmqctl -q -n rabbit set_permissions -p /influxdb guest ".*" ".*" ".*"
```
Download the rabbitmqadmin from the RabbitMQ server:
```
# curl -o rabbitmqadmin  http://rabbitmq.example.com:15672/cli/rabbitmqadmin
# chmod +x ./rabbitmqadmin
```
Declare the exchange:
```
# ./rabbitmqadmin declare exchange name=influxdb type=topic durable=true
exchange declared
```
Declare a queue:
```
# ./rabbitmqadmin --vhost=/influxdb declare queue name=influxq auto_delete=false durable=true
queue declared
```

Create a binding from the exchange to the queue. This will route the messages coming into that exchange to go to the influxq queue.

```
# ./rabbitmqadmin --vhost=/influxdb declare binding source=influxdb destination=influxq routing_key=""
```

Please check your configuration to confirm you see messages coming in before attempting to drain it. This can be done via the webinterface on rabbitmq.example.com:15672 or the rabbitmqadmin tool:

```
./rabbitmqadmin --vhost=/influxdb list queues
+---------+----------+
|  name   | messages |
+---------+----------+
| influxq | 13       |
+---------+----------+
```

To summarize:


| Vhost     | Exchange | Routing Key | Queue   |
|-----------|----------|-------------|---------|
| /influxdb | influxdb | ""          | influxq |



## Filling the queue


### Telegraf

Adding metrics from Telegraf to RabbitMQ, use the AMQP output:

```
[[outputs.amqp]]
    url = "amqp://rabbit:rabbit@rabbitmq.example.com:5672/%2Finfluxdb"
    auth_method = "PLAIN"
    exchange = "influxdb"
```

## Consuming the queue


Drain RabbitMQ, I am using the dump queue from [dubek/rabbitmq-dump-queue](https://github.com/dubek/rabbitmq-dump-queue).

Please the rabbitmq-dump-queue in /usr/local/bin (or adjust the script)

## Configuration

These variables are set in the script:

```
TMPDIR=/tmp
MESSAGES=16
RABBITMQHOST="rabbit.example.com"
VHOST="%2Finfluxdb"
QUEUE="influxq"
USER="rabbit"
PASS="rabbit"
INFLUXDB_HOST="influxdb.example.com"
INFLUXDB_DB="telegraf"
```

The streamer shell script will read out the queue in batches defined in $MESSAGES, default is 16.
If there are no messages, it will wait 10 seconds before reading out again. As long as there are messages, it will push them to InfluxDB as fast as it can. Please note that each message may contain a multitude of metric lines.

```
 ./rabbitmqadmin --vhost=/influxdb list queues
+---------+----------+
|  name   | messages |
+---------+----------+
| influxq | 2        |
+---------+----------+
```

```
./streamer.sh
Submitting 92 /tmp/linefile
HTTP/1.1 100 Continue

HTTP/1.1 204 No Content
Content-Type: application/json
Request-Id: 7d116621-d7da-11e6-9584-000000000000
X-Influxdb-Version: 1.1.1
Date: Wed, 11 Jan 2017 08:46:48 GMT

No messages, sleeping
````

Running
===
Make sure to set the variables correctly.

After that, simple run the script, it will start draining the queue and posting to InfluxDB. 
```
# ./streamer.sh
Submitting 5570 /tmp/linefile ...  done
Submitting 6262 /tmp/linefile ...  done
Submitting 5656 /tmp/linefile ...  done
Submitting 5570 /tmp/linefile ...  done
Submitting 5875 /tmp/linefile ...  done
Submitting 6034 /tmp/linefile ...  done
```

Issues
===
Handling errors (http response != 204):
```
Submitting 5607 /tmp/linefile ... Unexpected response, aborting.
```

Attemping to run multiple identical streamers. If this is required, change the variables in the script.
```
Lockfile present
Please check why. Submit the last metrics and remove the lockfile /var/run/streamer
curl -s -q -i -XPOST "http://influxdb.example.com:8086/write?db=telegraf" --data-binary @/tmp/linefile
```

After every succesful POST, it will remove the linefile afterwards. If the linefile is still present they may have not been submitted, these can be manually resubmitted.
```
Possible unsubmitted metrics found.
curl -s -q -i -XPOST "http://influxdb.example.com:8086/write?db=telegraf" --data-binary @/tmp/linefile
```
