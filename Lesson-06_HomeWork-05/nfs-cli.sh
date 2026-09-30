#! /bin/bash

# Этот скрипт должен запускаться из под root

# Входные параметры: 1- ip адрес сервера (по умолчанию 192.168.11.150)

if [[ -z "$1" ]]; then
  SRV_IP=192.168.11.150
else
  SRV_IP=$1
fi

apt-get update

# Установим пакет с NFS-клиентом
apt-get install -y nfs-common

# Добавляем в /etc/fstab строку для автомонтирования NFS-папки
# vers=3: Принудительно использует протокол NFSv3 для подключения.
# noauto: Запрещает системе монтировать этот сетевой диск автоматически в момент загрузки ОС.
# x-systemd.automount: Самая полезная опция в этой связке. Она передает управление монтированием демону systemd.
# 0 0: Первое число отключает резервное копирование утилитой dump, второе — отключает проверку диска утилитой fsck при загрузке (сетевые диски проверять с клиента нельзя).
echo "$SRV_IP:/srv/share/ /mnt nfs vers=3,noauto,x-systemd.automount 0 0" >> /etc/fstab

# Перезагружаем конфигурацию systemd, чтобы он прочитал изменения в fstab
systemctl daemon-reload

# Запускаем автоматически созданный automount-юнит для NFS-папки
#systemctl start mnt.automount
#
systemctl restart remote-fs.target
