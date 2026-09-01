#! /bin/bash
apt-get update
apt-get install -y nginx
echo "<h1> Hellow worl from Vagrant!</h1>" > /var/www/html/index.html
