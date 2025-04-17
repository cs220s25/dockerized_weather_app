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
