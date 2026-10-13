#! /bin/bash

# Этот скрипт должен запускаться из под root

# Входные параметры: 1- ip адрес сервера (по умолчанию 192.168.11.150)

if [[ -z "$1" ]]; then
  SRV_IP=192.168.11.150
else
  SRV_IP=$1
fi

# Создаем файл с конфигурацией для сервиса
cat > /etc/default/watchlog << EOF
# Configuration file for my watchlog service
# Place it to /etc/default
# File and word in that file that we will be monit
# Keyword
WORD="ALERT"
# File
LOG=/var/log/watchlog.log
EOF

# Создаем файл с логами, содержащими ключевое лово ALERT
cat > /var/log/watchlog.log << EOF
2026-10-01 01:10:20, ALERT: alert event occurred
2026-10-02 02:11:21, NOTIFY: noteworthy event occurred
2026-10-03 03:12:22, ALERT: alert event occurred
2026-10-04 04:13:23, NOTIFY: noteworthy event occurred
2026-10-05 05:14:24, ALERT: alert event occurred
2026-10-06 06:15:25, NOTIFY: noteworthy event occurred
EOF

# Создадим скрипт
cat > /opt/watchlog.sh << EOF
#!/bin/bash

# Input params: 1- keyword (default ALERT); 2- log file (default /var/log/watchlog.log)

if [[ -z "\$1" ]]; then
  WORD=ALERT
else
  WORD=\$1
fi

if [[ -z "\$2" ]]; then
  LOG=/var/log/watchlog.log
else
  LOG=\$2
fi

# Checking if a file exists
if [[ ! -f "\$LOG" ]]; then
    echo "Error: File '\$LOG' not found!"
    exit 1
fi

DATE="\$(date +'%Y-%m-%d %H:%M:%S')"

# Searching for a keyword in a log file
if grep "\$WORD" "\$LOG" &> /dev/null
then
  logger "\$DATE: I found word: '\$WORD' in '\$LOG', Master!"
#  echo "\$DATE: I found word: '\$WORD' in '\$LOG', Master!"
else
  logger "\$DATE: Word '\$WORD' not found in '\$LOG'"
#  echo "\$DATE: Word '\$WORD' not found in '\$LOG'"
exit 0
fi
EOF

chmod +x /opt/watchlog.sh

# Создадим юнит для сервиса:

# В файле службы (.service), который вызывается этим таймером, секция [Install] не нужна, так как служба управляется таймером, а не загрузкой системы.
cat > /etc/systemd/system/watchlog.service << EOF
[Unit]
Description=My watchlog service
After=network.target

[Service]
EnvironmentFile=/etc/default/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
# oneshot если скрипт выполняется разово и завершает работу, simple (по умолчанию), если сервис должен работать постоянно
Type=oneshot
EOF

# Создадим юнит для таймера:

# В systemd.timer не нужно указывать Unit=watchlog.service, потому что systemd автоматически связывает таймер с сервисом по его имени.
# У таймера watchlog.timer по умолчанию активируется сервис с таким же именем: watchlog.service
# (то есть systemctl start watchlog.timer запустит watchlog.service).
# Это правило работает автоматически и соответствует стандартной практике в systemd.
# Если таймер должен запускать другой сервис, тогда Unit= имеет смысл.
# В 99% случаев лучше просто назвать таймер так же, как сервис (watchlog.timer → watchlog.service).
cat > /etc/systemd/system/watchlog.timer << EOF
[Unit]
Description=Run watchlog script every 30 second
[Timer]
# First launch one minute after booting.
OnBootSec=1min
# Run every 30 second
OnUnitActiveSec=30
# Повышает точность systemd (по умолчанию погрешность может быть до 1 минуты)
AccuracySec=1ms
[Install]
# Укажем системе, что данный таймер должен автоматически активироваться (заводиться) при загрузке операционной системы.
WantedBy=timers.target
EOF

systemctl enable --now watchlog.timer


