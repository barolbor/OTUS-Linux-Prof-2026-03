#! /bin/bash

# Этот скрипт должен запускаться из под root

# Входные параметры: 1- ip адрес сервера (по умолчанию 192.168.11.150)

if [[ -z "$1" ]]; then
  SRV_IP=192.168.11.150
else
  SRV_IP=$1
fi

# Добавим свой репозиторий
cat >> /etc/yum.repos.d/obb.repo << EOF
[obb]
name=obb Repository for AlmaLinux 10
baseurl=http://$SRV_IP/repo
gpgcheck=0
enabled=1
EOF

# Установим ngix из своего репозитория, а зависимости из официального
dnf install -y nginx --setopt=obb.priority=1

# Изменим дефолтную страницу
cat > /usr/share/nginx/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
<title>nginx from custom repo OBB!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to OBB nginx running on Client!</h1>
<h2>This nginx installed from custom repo OBB!</h2>
</body>
</html>
EOF

# Запустим nginx и добавим его в автозапуск
systemctl enable --now nginx
#systemctl start nginx
systemctl status nginx
