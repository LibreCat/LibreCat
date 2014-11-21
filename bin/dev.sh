#!/bin/sh

# run me as root!

# start elasticsearch
docker run -d -p 9200:9200 -p 9300:9300 \
-v /data:/data dockerfile/elasticsearch \
/elasticsearch/bin/elasticsearch -Des.config=/data/elasticsearch.yml

# start mongodb
docker run -d -p 27017:27017 \
-v /data/mongo_data:/data/db --name mongodb dockerfile/mongodb
