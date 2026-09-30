#! /bin/bash

# Этот скрипт должен запускаться из под root

# Входные параметры: 1 - ip адрес клиента (по умолчанию 192.168.11.151)

if [[ -z "$1" ]]; then
  CLI_IP=192.168.11.151
else
  CLI_IP=$1
fi

apt-get update

# Установим сервер NFS:
apt-get install -y nfs-kernel-server

# Создаём и настраиваем директорию для экспорта

mkdir -p /srv/share/upload
chown -R nobody:nogroup /srv/share
chmod 0777 /srv/share/upload

# Cоздаём в файле /etc/exports структуру, которая позволит экспортировать директорию
# Доступ для одного конкретного CLI_IP (максимальная безопасность)
# rw - (read-write) разрешает клиенту читать и записывать данные в экспортируемую сетевую папку NFS.
# sync - заставляет NFS-сервер работать в режиме гарантированной сохранности данных, клиент ждет, пока сервер запишет данные на сам накопитель.
# root_squash - певращает root клиента в nobody на сервере.
# no_subtree_check - отключает проверку поддеревьев файловой системы на NFS-сервере.
echo "/srv/share $CLI_IP/32(rw,sync,root_squash,no_subtree_check)" >> /etc/exports

# Экспортируем ранее созданную директорию
exportfs -r
