# apache-ignite-cdc
Some stuff for Apache Ignite CDC (configs, libs, etc)

# Contents
1. [Binary distribs](#binary-distribs)
2. [How to setup clusters](#how-to-setup-clusters)
3. [Quick Apache Kafka topic creation](#quick-apache-kafka-topic-creation)

## Binary distribs
[ignite-cdc-ext-2.15.0-bin.zip](http://niflscud.red/static/distrib/ignite-cdc-ext-2.15.0-bin.zip) \
[ignite-cdc-ext-2.14.0-bin.zip](http://niflscud.red/static/distrib/ignite-cdc-ext-2.14.0-bin.zip)

## How to setup clusters

> Note: both clusters run on the same machine but on different ports and each cluster consists of one instance **for simplicity**

> Note: CDC in this example uses Kafka as a transport
### Prepare
- Get Apache Ignite, CDC extention (ignite-cdc-ext) and configs
- Save configs to /tmp/config (or adjust paths for \*-kafkaToIgnite.properties in configs)
- Create Kafka topics (see [Quick Apache Kafka topic creation](#quick-apache-kafka-topic-creation))
- Unpack ignite-cdc-ext-*-bin.zip
    - move contents of ignite-cdc-ext/bin/\* to apache ignite bin dir
    - move contents of ignite-cdc-ext/libs/\* to apache ignite libs dir

### Start
- Run the following commands in Apache Ignite directory to start Ignite:
```
$ bin/ignite.sh /tmp/config/cluster0_native-persistence-with-cdc_node0.xml
$ bin/ignite.sh /tmp/config/cluster1_native-persistence-with-cdc_node0.xml
```

- Activate clusters:
```
$ bin/control.sh --user ignite --password ignite --port 11211 --baseline      # get sure (all) instance(s) started
$ bin/control.sh --user ignite --password ignite --port 11211 --set-state active --yes
$ bin/control.sh --user ignite --password ignite --port 11212 --baseline      # get sure (all) instance(s) started
$ bin/control.sh --user ignite --password ignite --port 11212 --set-state active --yes
```

- Create tables on both clusters in order to get ability to run SELECT on replica (CDC with SQL)
```
$ echo 'CREATE TABLE IF NOT EXISTS CDC_CACHE (ID INT NOT NULL, TVAL INT NOT NULL, PAYLOAD VARCHAR, PRIMARY KEY(ID)) WITH "CACHE_NAME=CDC_CACHE,KEY_TYPE=SOME_KEY_TYPE,VALUE_TYPE=SOME_VAL_TYPE";' | bin/sqlline.sh -n ignite -p ignite -u jdbc:ignite:thin://127.0.0.1:10800
$ echo 'CREATE TABLE IF NOT EXISTS CDC_CACHE (ID INT NOT NULL, TVAL INT NOT NULL, PAYLOAD VARCHAR, PRIMARY KEY(ID)) WITH "CACHE_NAME=CDC_CACHE,KEY_TYPE=SOME_KEY_TYPE,VALUE_TYPE=SOME_VAL_TYPE";' | bin/sqlline.sh -n ignite -p ignite -u jdbc:ignite:thin://127.0.0.1:10801
```
- Run CDC
```
$ bin/ignite-cdc.sh /tmp/config/cluster0_native-persistence-with-cdc_node0.xml
$ bin/ignite-cdc.sh /tmp/config/cluster1_native-persistence-with-cdc_node0.xml
```

- Run kafta-to-ignite
```
$ bin/kafka-to-ignite.sh /tmp/config/cluster0_kafka-to-ignite_client.xml
$ bin/kafka-to-ignite.sh /tmp/config/cluster1_kafka-to-ignite_client.xml
```

## Quick Apache Kafka topic creation
Download and unpack Apache Kafka distrib and then run the following commands (from [docs](https://kafka.apache.org/documentation/#quickstart)):
```
$ bin/zookeeper-server-start.sh config/zookeeper.properties &> /tmp/kafka-zookeeper.log &
$ bin/kafka-server-start.sh config/server.properties &>  /tmp/kafka-server.log &

$ bin/kafka-topics.sh --create --topic ignite-replication-0cl-to-1cl --bootstrap-server localhost:9092
$ bin/kafka-topics.sh --create --topic ignite-replication-1cl-to-0cl --bootstrap-server localhost:9092
$ bin/kafka-topics.sh --create --topic ignite-metadata-replication-1cl-to-0cl --bootstrap-server localhost:9092
$ bin/kafka-topics.sh --create --topic ignite-metadata-replication-0cl-to-1cl --bootstrap-server localhost:9092
```
