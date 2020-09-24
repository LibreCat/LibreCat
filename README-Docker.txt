
1) Run the docker-compose to start mysql and elasticsearch

$ docker-compose up -d

(use docker-compose down to shut down)

2) Run the docker build command to create a new Docker image

docker build -t librecat/librecat .

Drink coffee.. this takes +/- 30 mins

3) Run the docker container and get access to the Librecat server

docker run --network librecat_default -e LIBRECAT_INIT=1 -p 5002:5002 -it librecat/librecat
