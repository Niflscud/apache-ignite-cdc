# apache-ignite-cdc
Some stuff for Apache Ignite CDC (configs, libs, etc)

# Contents
1. [Binary distribs](#binary-distribs)
2. [How to setup clusters](#how-to-setup-clusters)
   1. [Prepare](#prepare)
   2. [Start](#start)
   3. [Active-active replication](#active-active-replication)
   4. [Load testing](#load-testing)
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
    - move ignite-cdc-ext/bin/\* to apache ignite bin dir
    - move ignite-cdc-ext/libs/\* to apache ignite libs dir

### Start
Run the following commands in Apache Ignite directory to start Ignite:
```
$ bin/ignite.sh /tmp/config/cluster0_native-persistence-with-cdc_node0.xml
$ bin/ignite.sh /tmp/config/cluster1_native-persistence-with-cdc_node0.xml
```

Activate clusters:
```
$ bin/control.sh --user ignite --password ignite --port 11211 --baseline      # get sure (all) instance(s) started
$ bin/control.sh --user ignite --password ignite --port 11211 --set-state active --yes
$ bin/control.sh --user ignite --password ignite --port 11212 --baseline      # get sure (all) instance(s) started
$ bin/control.sh --user ignite --password ignite --port 11212 --set-state active --yes
```

Create tables on both clusters in order to get ability to run SELECT on replica (CDC with SQL)
```
$ echo 'CREATE TABLE IF NOT EXISTS CDC_CACHE (ID INT NOT NULL, TVAL INT NOT NULL, PAYLOAD VARCHAR, PRIMARY KEY(ID)) WITH "CACHE_NAME=CDC_CACHE,KEY_TYPE=SOME_KEY_TYPE,VALUE_TYPE=SOME_VAL_TYPE";' | bin/sqlline.sh -n ignite -p ignite -u jdbc:ignite:thin://127.0.0.1:10800 2> /dev/null
$ echo 'CREATE TABLE IF NOT EXISTS CDC_CACHE (ID INT NOT NULL, TVAL INT NOT NULL, PAYLOAD VARCHAR, PRIMARY KEY(ID)) WITH "CACHE_NAME=CDC_CACHE,KEY_TYPE=SOME_KEY_TYPE,VALUE_TYPE=SOME_VAL_TYPE";' | bin/sqlline.sh -n ignite -p ignite -u jdbc:ignite:thin://127.0.0.1:10801 2> /dev/null
```
Run CDC
```
$ bin/ignite-cdc.sh /tmp/config/cluster0_native-persistence-with-cdc_node0.xml
$ bin/ignite-cdc.sh /tmp/config/cluster1_native-persistence-with-cdc_node0.xml
```

Run kafta-to-ignite
```
$ bin/kafka-to-ignite.sh /tmp/config/cluster0_kafka-to-ignite_client.xml
$ bin/kafka-to-ignite.sh /tmp/config/cluster1_kafka-to-ignite_client.xml
```

### Active-active replication
> Note: TVAL should monotonously increase for active-active replication ([conflictResolveField](https://ignite.apache.org/docs/latest/extensions-and-integrations/change-data-capture-extensions#cacheversionconflictresolver-implementation))

Insert test data into the first database:
```
$ bin/sqlline.sh -n ignite -p ignite -u jdbc:ignite:thin://127.0.0.1:10800
0: jdbc:ignite:thin://127.0.0.1:10800> INSERT INTO CDC_CACHE VALUES (0,0,'a'),(1,1,'b'),(2,2,'c'),(3,3,NULL),(4,4,'aa'),(5,5,'bb'),(6,6,'cc'),(7,7,NULL),(8,8,NULL),(9,9,NULL);
```
Insert test data into the second database:
```
$ bin/sqlline.sh -n ignite -p ignite -u jdbc:ignite:thin://127.0.0.1:10801
0: jdbc:ignite:thin://127.0.0.1:10801> INSERT INTO CDC_CACHE VALUES (10,10,'a'),(11,11,'b'),(12,12,'c'),(13,13,NULL),(14,14,'aa'),(15,15,'bb'),(16,16,'cc'),(17,17,NULL),(18,18,NULL),(19,19,NULL);
```
Wait approx. 1-2 minutes, and then:
```
$ bin/sqlline.sh -n ignite -p ignite -u jdbc:ignite:thin://127.0.0.1:10800
0: jdbc:ignite:thin://127.0.0.1:10800> SELECT * FROM CDC_CACHE ORDER BY ID;
$ bin/sqlline.sh -n ignite -p ignite -u jdbc:ignite:thin://127.0.0.1:10801
0: jdbc:ignite:thin://127.0.0.1:10801> SELECT * FROM CDC_CACHE ORDER BY ID;
```
Both SELECT should return equal data:
```
+----+------+---------+
| ID | TVAL | PAYLOAD |
+----+------+---------+
| 0  | 0    | a       |
| 1  | 1    | b       |
| 2  | 2    | c       |
| 3  | 3    |         |
| 4  | 4    | aa      |
| 5  | 5    | bb      |
| 6  | 6    | cc      |
| 7  | 7    |         |
| 8  | 8    |         |
| 9  | 9    |         |
| 10 | 10   | a       |
| 11 | 11   | b       |
| 12 | 12   | c       |
| 13 | 13   |         |
| 14 | 14   | aa      |
| 15 | 15   | bb      |
| 16 | 16   | cc      |
| 17 | 17   |         |
| 18 | 18   |         |
| 19 | 19   |         |
+----+------+---------+
```
### Load testing
You can generate some data using bin/simple-dataset-generator.sh
```
$ path/to/repo/bin/simple-dataset-generator.sh -f some-dataset.sql -s 20 -e 1000000   # generate inserts with ids from 20 to 1'000'000 and save output in some-dataset.sql file
$ bin/sqlline.sh -n ignite -p ignite -u jdbc:ignite:thin://127.0.0.1:10801 -f some-dataset.sql
```
Adjust simple-dataset-generator.sh for your needs

Get the data on another cluster:
```
$ bin/sqlline.sh -n ignite -p ignite -u jdbc:ignite:thin://127.0.0.1:10800
0: jdbc:ignite:thin://127.0.0.1:10800> SELECT COUNT(*) FROM CDC_CACHE;
0: jdbc:ignite:thin://127.0.0.1:10800> SELECT * FROM CDC_CACHE ORDER BY ID;
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
