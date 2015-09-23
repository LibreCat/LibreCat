#!/bin/sh

case "$1" in
    init)
      docker run -d -p 9200:9200 -p 9300:9300 -v $PWD/data/es:/data --name elastic elasticsearch
      docker run -d -p 27017:27017 -v $PWD/data/mongo:/data/db --name mongodb mongo
      carton install --deployment
      carton exec catmandu import YAML to search --bag researcher < devel/researcher.yml
      carton exec catmandu import YAML to search --bag publication < devel/department.yml
      echo '{"_id": "1", "latest" : "0"}' | carton exec catmandu import YAML
      echo 'Start plackup in dev mode:\n carton exec plackup -E development -s Starman bin/app.pl'
      ;;
    start)
      docker start elastic
      docker start mongodb
      ;;
    stop)
      docker stop elastic
      docker stop mongodb
      ;;
    destroy)
      docker rm elastic
      docker rm mongodb
      ;;
    *)
      echo $"Usage: $0 {init|start|stop|destroy}"
      exit 1
esac
