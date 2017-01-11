# RabbitMQ HA

Assuming you have 3 machines:

rabbitmq-1.example.com
rabbitmq-2.example.com
rabbitmq-3.example.com

Please note I am assuming a functional DNS.

And you have vhost '/ha' and queue 'haqueue' you want to make highly available.

```
# rabbitmqctl add_vhost /ha 
Creating vhost "/ha" ...

# /usr/sbin/rabbitmqctl -q -n rabbit set_permissions -p /ha guest ".*" ".*" ".*"

# ./rabbitmqadmin --vhost=/ha declare queue name=haqueue auto_delete=false durable=true
queue declared

# ./rabbitmqadmin --vhost=/ha declare exchange name=ha type=direct durable=true
exchange declared
```

## Clustering

First, make sure all hosts have the same erlang cookie. Best is to use configuration management tools such as [Ansible]( http://docs.ansible.com/ansible/list_of_messaging_modules.html) or [Puppet](https://github.com/puppetlabs/puppetlabs-rabbitmq).

Follow the steps at [https://www.rabbitmq.com/clustering.html]

Example of adding a second node to the cluster.
```
[root@rabbitmq-2 ~]# rabbitmqctl cluster_status
 
Cluster status of node 'rabbit@rabbitmq-2' ...
 
[{nodes,[{disc,['rabbit@rabbitmq-2']}]},
 
 {running_nodes,['rabbit@rabbitmq-2']},
 
 {cluster_name,<<"rabbit@rabbitmq-2.rinis.nl">>},
 
 {partitions,[]},
 
 {alarms,[{'rabbit@rabbitmq-2',[]}]}]
 
[root@rabbitmq-2 ~]# rabbitmqctl stop_app
 
Stopping node 'rabbit@rabbitmq-2' ...
 
 
 
[root@rabbitmq-2 ~]# rabbitmqctl join_cluster rabbit@rabbitmq-1
 
Clustering node 'rabbit@rabbitmq-2' with 'rabbit@rabbitmq-1' ...
 
[root@rabbitmq-2 ~]# rabbitmqctl start_app
 
 
 
 
Starting node 'rabbit@rabbitmq-2' ...
 
 
[root@rabbitmq-2 ~]#  rabbitmqctl cluster_status
 
 
 
 
Cluster status of node 'rabbit@rabbitmq-2' ...
 
[{nodes,[{disc,['rabbit@rabbitmq-1','rabbit@rabbitmq-2']}]},
 
 {running_nodes,['rabbit@rabbitmq-1','rabbit@rabbitmq-2']},
 
 {cluster_name,<<"rabbit@rabbitmq-1.rinis.nl">>},
 
 {partitions,[]},
 
 {alarms,[{'rabbit@rabbitmq-1',[]},{'rabbit@rabbitmq-2',[]}]}]
```

## HA Queues

Set up the policy for everything in the vhost, or just the haqueue and the exchange "ha".

```
rabbitmqctl set_policy ha-all ".*" '{"ha-mode":"all","ha-sync-mode":"automatic"}'


# rabbitmqctl -p /ha set_policy ha-all "(^haqueue$|^ha$)" '{"ha-mode":"all","ha-sync-mode":"automatic"}'
Setting policy "ha-all" for pattern "(^haqueue$|^ha$)" to "{\"ha-mode\":\"all\",\"ha-sync-mode\":\"automatic\"}" with priority "0" ...
```

![rabbitmq-ha-exchange](https://github.com/msteggink/rabbitmq-to-influxdb/raw/master/images/ha-exchange.png "HA Exchange")

![rabbitmq-ha-queue](https://github.com/msteggink/rabbitmq-to-influxdb/raw/master/images/ha-queue.png "HA Queue")
