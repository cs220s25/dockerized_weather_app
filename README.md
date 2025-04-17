## Overview

This repo contains a *Dockerized* version of the weather app where the `collector`, Redis DB, and `server` run as three separate Docker containers within a single network.


![architecture](architecture.png)



## Manual Build of the Collector Container

* Study the `collector/Dockerfile`
* Build the container


  ```
  docker build -t collector .
  ```

## Manual Build of the Server Container

* Study the `server/Dockerfile`
* Build the container

  ```
  docker build -t server .
  ```


## Create `.env` Files

You should **NEVER** use the `COPY` command in. `Dockerfile` to copy sensitive information into a Docker image.  Instead, you should add that information to the container when it is launched.

We will create `collector/collector.env` and `server/server.env` and then *mount* those files as `.env` files in the respective containers.

* Create `collector/collector.env` with:

  ```
  REDIS_HOST=redisdb
  REDIS_PORT=6379
  API_KEY=<WEATHER API KEY>
  ```
  
  Note that the `REDIS_HOST` is **NOT** `localhost`.  The Redis database will run in a separate container, and the `collector` will refer to it by the name `redisdb`.
  
  
* Create `server/server.end` with

  ```
  REDIS_HOST=redisdb
  REDIS_PORT=6379
  ```  

  The `server` will also connect to the Redis database as a separate container.  It does NOT use the Weather API, so we omit this form the `.env` file.



## Manual Launch of the System

* Create a Docker network named `weather`

  ```
  docker network create weather
  ```
  
* Launch a Redis container using the [official Docker image](https://hub.docker.com/_/redis)

  ```
  docker run -d --network weather --name redisdb -v $(pwd)/data:/data redis redis-server --save 10 1
  ```
  * `-d` - daemonize the container (run in the background)
  * `--network weather` - Run the container in the `weather` network
  * `--name redisdb` Name the container `redisdb`
  * `-v $(pwd)/data:/data` - mount the folder `data` as `/data` in the container.  This is where Redis saves `dump.rdb`.  NOTE: mounts must be specified as an absolute path.  `$(pwd)` used [command substitution](https://www.gnu.org/software/bash/manual/html_node/Command-Substitution.html) to get the absolute path of the current directory.
  * `redis-server --save 10 1` - From the [official image documentation](https://hub.docker.com/_/redis), run the Redis server and tell it to save every 10 minutes (if at least 1 value has been modified)


* Launch an instance of the `collector`

  ```
  docker run -d --network weather --name collector -v $(pwd)/collector/collector.env:/app/.env  collector
  ```
  * `-d` - daemonize the container (run in the background)
  * `--network weather` - Run the container in the `weather` network
  * `--name collector` - Name the container `collector`
  * `-v $(pwd)/collector/collector.env:/app/.env` - mount `collector/collector.env` as `/app/.env` in the container.  

* Launch an instance of the `server`

  ```
  docker run -d --network weather --name server -p 80:80 -v $(pwd)/server/server.env:/app/.env server
  ```
  
  * `-d` - daemonize the container (run in the background)
  * `--network weather` - Run the container in the `weather` network
  * `--name server` - Name the container `server`
  * `-p 80:80` - Map port 80 in the container to port 80 on `localhost`
  * `-v $(pwd)/server/server.env:/app/.env` - mount `server/server.env` as `/app/.env` in the container.



## Useful Commands

* `docker ps` - see the running images
* `docker logs <name>` -- see the logs for the `<name>` container.  This works even if a container is stopped - useful when it crashes on startup.
* `docker exec <name> bash` - create a bash shell *inside* the `<name>` container.  This is helpful to *see* the files inside the container while it is running
* `docker rm -f <name>` - Stop and delete the `<name>` container.




## The `build.sh`, `up`, and `down` scripts

The repo contains three scripts to automate the steps in the previous sections.

* `build.sh`
  * Build the `collector` and `server` images.  If any changes are made to files, this will rebuild the container image.
  * Create the `weather` Docker network if it does not already exist.

* `up`
  * Verify that `collector/collector.env` and `server/server.env` exist
  * Start the Redis container - NOTE: `-p 6379:6379` in this script maps the Reis port to `localhost`.  This allows you to run `redis-cli` on your laptop to inspect the data in the database *inside* the container
  * Start the `collector` container (do this 2nd because it immediately writes to Redis)
  * Start the `server` container

* `down`
  * Stop (and remove) the server
  * Stop (and remove) the collector
  * Stop (and remove) the redis container (do this last to ensure all data is saved.



## Manual AWS Deploy

To deploy on AWS, we have to do following:

* Install `git` and clone the repository

  ```
  sudo yum install -y git
  git clone https://github.com/cs220s25/dockerized_weather_app.git
  ```
  
* Install docker, start it, and make it available to the `ec2-user`.  


  ```
  yum install -y docker
  systemctl enable docker
  systemctl start docker
  usermod -a -G docker ec2-user
  ```
  
  The `usermod` command adds `ec2-user` to the `docker` group.  This allows `ec2-user` to run `docker` without `sudo`.
  
  NOTE:  After this step you need to log out and log back in to the EC2 instance because the shell only reads group membership at login.
  

* Create `collector/collector.env`:

  ```
  REDIS_HOST=redisdb
  REDIS_PORT=6379
  API_KEY=<api key>
  ```

* Create `server/server.env`:

  ```
  REDIS_HOST=redisdb
  REDIS_PORT=6379
  ```
  
* Build the container images and create the Docker network.


  ```
  ./build.sh
  ```
  
* Launch the system.

  ```
  ./up
  ```


## Validation

If everything worked, you will be able to get the current temperature in Bethlehem by accessing the system.

  ```
  curl localhost
  ```
  
If this works, you can verify that your EC2 instance is configured correctly by connecting to the system using a web browser

  ```
  http://<EC2 IP address>
  ```
  
## Stop the System
  
  
If you need to stop the system, use the `down` script:
  
  ```
  ./down
  ```  
  
  
## (Mostly) Automated Deploy

You can perform *most* of the steps using the User Data section of the launch.  


* When you create the EC2 instance, place the commands in `userdata.sh` in the User Data section under advanced:


  ```
  #!/bin/bash
  yum install -y docker
  systemctl enable docker
  systemctl start docker
  # Add ec2-user to the docker group so that it can run docker commands without sudo.
  usermod -a -G docker ec2-user

  yum install -y git
  git clone https://github.com/cs220s25/dockerized_weather_app.git /weather

  cd /weather
  ./build.sh
  ```

  * No need for `sudo` because the User Data script runs as `root`
  * The repo is cloned in `/weather` instead of in the `ec2-user` home directory
  * This builds the container images, but it does **NOT** start the app

* Wait for everything to be installed, and verify that you can run `docker` commands.

  ```
  docker ps
  ```
  
  * Because no containers are running, this should produce 

    ```
    CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
    ```

  * Look at `/var/log/cloud-init-output.log` to see the status of Cloud Init.
  * If you log in too soon the command will fail.  Wait for Cloud Init to finish, log out, and log back in.


* Create `collector/collector.env` and `server/server.env`

* Launch the system

  ```
  cd /weather
  ./up
  ```