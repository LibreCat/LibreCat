### Building Docker

Required when one or more of these is true:

  - First installation of the LibreCat docker on your machine
  - You have made changes to the `docker` directory
  - You changed the `Dockerfile`
  - You changed the `cpanfile`

This build will take about 30 minutes minutes (depending on your network
speed and CPU).

```
$ docker build --rm -t librecat/librecat .
```

### Running the LibreCat application

Check first if a librecat image exists:

```
$ docker image ls
```

When you see a librecat/librecat image you are ok

Run the docker-compose to boot up MySQL, Elasticsearch and LibreCat

```
$ docker-compose up -d
```

(use docker-compose down to shut down)

Connect to the librecat instance  :

```
$ docker exec -it [docker_image] bash -l
```

check the docker_image id with:

```
$ docker ps
```

When you need gearman services, then run inside the container:

```
sudo gearmand &
```

### Settings

Some settinsg in the `docker-compose.yml` that might be helpful:

By default the LibreCat will open port 5002 and Plackup will
be running

```
MYSQL_ROOT_PASSWORD: librecat
LIBRECAT_ENV: development
WAIT_HOSTS: mysql:3306, elasticsearch:9200
WAIT_HOSTS_TIMEOUT: 60
```

Stop the automatic boot of plackup with:

```
LIBRECAT_PLACKUP: 0
```

At every boot the database will be initialized with a clean setup. You might
want to switch this off with the setting:

```
LIBRECAT_INIT: 0
```

At every boot the database will be filled with demo records. You might want to
switch this off with the setting:

```
LIBRECAT_DEMO: 0
```

### Development

For development purposes you might want to mount the librecat source directory
on your local system in the container. Do this by adding a volume:

```
volumes:
  - ".:/opt/librecat"
```

Where `.` is the current directory where the LibreCat sources can be found.

!!! When overwriting the /opt/librecat with the local sources a layers.yml file
must be created that points to the `/tmp/docker` directory:

```
$ cat layers.yml
- /tmp/docker
```
