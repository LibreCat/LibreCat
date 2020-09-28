
1) Run the docker-compose to start mysql and elasticsearch

$ docker-compose up -d

(use docker-compose down to shut down)

2) Run the docker build command to create a new Docker image

docker build --rm -t librecat/librecat .

Drink coffee.. this takes +/- 30 mins

This step you only need to when no librecat/librecat container exists yet on your
machine, or when you edited one or more of the files in docker/ Dockerfile

3) Run the docker container and get access to the Librecat server

docker run --network librecat_default -e LIBRECAT_INIT=1 -p 5002:5002 -it librecat/librecat

After the first initial run LIBRECAT_INIT can be set to 0.

4) Connect to Librecat web interface : http://localhost:5002

5) Connect to the command line

docker exec -it [docker_image] "/usr/bin/bash -l"

check the docker_image with

docker ps

6) When you need gearman services, then run inside the container:

sudo gearmand &
