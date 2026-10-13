#! /bin/bash

# Этот скрипт должен запускаться из под root

# Устанавливаем nginx:
apt update
apt install -y nginx

# Юнит для запуска нескольких сервисов nginx
cat > /etc/systemd/system/nginx@.service << EOF
# Stop dance for nginx
# =======================
#
# ExecStop sends SIGQUIT (graceful stop) to the nginx process.
# If, after 5s (--retry QUIT/5) nginx is still running, systemd takes control
# and sends SIGTERM (fast shutdown) to the main process.
# After another 5s (TimeoutStopSec=5), and if nginx is alive, systemd sends
# SIGKILL to all the remaining processes in the process group (KillMode=mixed).
#
# nginx signals reference doc:
# http://nginx.org/en/docs/control.html
#
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target
ConditionFileIsExecutable=/usr/sbin/nginx

[Service]
Type=forking
PIDFile=/run/nginx-%I.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-%I.conf -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx-%I.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

# Файл с настройками для 1-го сервиса
cat > /etc/nginx/nginx-1.conf << EOF
user www-data;
worker_processes auto;
pid /run/nginx-1.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

events {
        worker_connections 768;
}

http {
        sendfile on;
        tcp_nopush on;
        types_hash_max_size 2048;
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
        ssl_prefer_server_ciphers on;
        access_log /var/log/nginx/access.log;
        gzip on;
        server {
                listen 8081 default_server;
                listen [::]:8081 default_server;
                root /usr/share/nginx/html-1;
                index index.html index.htm index.nginx-debian.html;
                server_name default_server;
                location / {
                        try_files \$uri \$uri/ =404;
                }
        }
}
EOF

# Файл с настройками для 2-го сервиса
cat > /etc/nginx/nginx-2.conf << EOF
user www-data;
worker_processes auto;
pid /run/nginx-2.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

events {
        worker_connections 768;
}

http {
        sendfile on;
        tcp_nopush on;
        types_hash_max_size 2048;
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
        ssl_prefer_server_ciphers on;
        access_log /var/log/nginx/access.log;
        gzip on;
        server {
                listen 8082 default_server;
                listen [::]:8082 default_server;
                root /usr/share/nginx/html-2;
                index index.html index.htm index.nginx-debian.html;
                server_name default_server;
                location / {
                        try_files \$uri \$uri/ =404;
                }
        }
}
EOF

# Дефолтная страница для 1-го сервиса
mkdir -p /usr/share/nginx/html-1/
cat > /usr/share/nginx/html-1/index.html << EOF
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx - 1!</title>
<style>
html { color-scheme: dark light; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx - 1!</h1>
<h2>This is the first instance running on port 8081.</h2>
</body>
</html>
EOF

# Дефолтная страница для 2-го сервиса
mkdir -p /usr/share/nginx/html-2/
cat > /usr/share/nginx/html-2/index.html << EOF
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx - 2!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx - 2!</h1>
<h2>This is the second instance running on port 8082.</h2>
</body>
</html>
EOF

# Запустим nginx`ы
systemctl enable --now nginx@1
systemctl enable --now nginx@2


