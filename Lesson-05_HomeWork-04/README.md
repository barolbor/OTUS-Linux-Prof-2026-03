# Домашнее задание
##  Практические навыки работы с ZFS
### Задание
1) Определить алгоритм с наилучшим сжатием:
   - определить, какие алгоритмы сжатия поддерживает zfs (gzip, zle, lzjb, lz4);
   - создать 4 файловых системы, на каждой применить свой алгоритм сжатия;
   - для сжатия использовать либо текстовый файл, либо группу файлов.
2) Определить настройки пула.
   - С помощью команды zfs import собрать pool ZFS.
   - Командами zfs определить настройки:
     - размер хранилища;
     - тип pool;
     - значение recordsize;
     - какое сжатие используется;
     - какая контрольная сумма используется.
3) Работа со снапшотами:
   - скопировать файл из удаленной директории;
   - восстановить файл локально. zfs receive;
   - найти зашифрованное сообщение в файле secret_message.

## Решение

### Vagrant 2.4.9, VirtualBox 7.2.16, на хосте с ОС Windows 11

Vagrant файл создает ВМ с гостевой ОС bento/ubuntu-24.04 со следующими параметрами:
* ОЗУ 8192Мб, CPU 2;
* 10 дисков по 1Gb;

Установим ZFS и создадим пулы

```bash
# Далее выполняем все команды из под рута
sudo -i

# Устанавливаем ZFS и unzip
apt update
...

apt upgrade
...

apt install zfsutils-linux unzip
...

zfs --version
zfs-2.2.2-0ubuntu9.5
zfs-kmod-2.2.2-0ubuntu9.4

# Список блочных устройств
lsblk
NAME                      MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
sda                         8:0    0  64G  0 disk
├─sda1                      8:1    0   1M  0 part
├─sda2                      8:2    0   2G  0 part /boot
└─sda3                      8:3    0  62G  0 part
  └─ubuntu--vg-ubuntu--lv 252:0    0  31G  0 lvm  /
sdb                         8:16   0   1G  0 disk
sdc                         8:32   0   1G  0 disk
sdd                         8:48   0   1G  0 disk
sde                         8:64   0   1G  0 disk
sdf                         8:80   0   1G  0 disk
sdg                         8:96   0   1G  0 disk
sdh                         8:112  0   1G  0 disk
sdi                         8:128  0   1G  0 disk
sdj                         8:144  0    1G  0 disk
sdk                         8:160  0    1G  0 disk

# Создадим 5 пулов из 2х дисков в режиме RAID 1
zpool create zfs_1 mirror /dev/sdb /dev/sdc
zpool create zfs_2 mirror /dev/sdd /dev/sde
zpool create zfs_3 mirror /dev/sdf /dev/sdg
zpool create zfs_4 mirror /dev/sdh /dev/sdi
zpool create zfs_5 mirror /dev/sdj /dev/sdk

# Список пулов
zpool list
NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
zfs_1   960M   114K   960M        -         -     0%     0%  1.00x    ONLINE  -
zfs_2   960M   122K   960M        -         -     0%     0%  1.00x    ONLINE  -
zfs_3   960M   116K   960M        -         -     0%     0%  1.00x    ONLINE  -
zfs_4   960M   122K   960M        -         -     0%     0%  1.00x    ONLINE  -
zfs_5   960M   116K   960M        -         -     0%     0%  1.00x    ONLINE  -
```

### 1. Определим алгоритм с наилучшим сжатием

```bash
# Определим, какие алгоритмы поддерживает zfs (gzip, zle, lzjb, lz4)
zfs get 2>&1 | grep -E "gzip|zle|lzjb|lz4"
        compression     YES      YES   on | off | lzjb | gzip | gzip-[1-9] | zle | lz4 | zstd | zstd-[1-19] | zstd-fast | zstd-fast-[1-10,20,30,40,50,60,70,80,90,100,500,1000]
# zfs поддерживает заданные алгоритмы сжатия: gzip, zle, lzjb, lz4

# Зададим разные алгоритмы сжатия для каждого пула
# gzip эквивалентен gzip-6
zfs set compression=gzip zfs_1
# lzjb оптимизирован для обеспечения высокой производительности и при этом обеспечивает достойный уровень сжатия данных.
zfs set compression=zle zfs_2
# lzjb оптимизирован для обеспечения высокой производительности и при этом обеспечивает достойный уровень сжатия данных.
zfs set compression=lzjb zfs_3
# lz4 — это высокопроизводительная замена алгоритму lzjb
zfs set compression=lz4  zfs_4
# zstd обеспечивает как высокую степень сжатия, так и высокую производительность, zstd эквивалентен zstd-3, ИИ рекомендует как альтернатиу устаревшему gzip
zfs set compression=zstd zfs_5

# Убедимся, что все пулы имеют разные алгоритмы сжатия
zfs get compression
NAME   PROPERTY     VALUE           SOURCE
zfs_1  compression  gzip            local
zfs_2  compression  zle             local
zfs_3  compression  lzjb            local
zfs_4  compression  lz4             local
zfs_5  compression  zstd            local

# Скачаем дамп демонстрационной базы данных PostgreSQL авиаперевозки по России.
wget -O ~/archive.zip "https://edu.postgrespro.ru/demo-small-20170815.zip" && unzip ~/archive.zip -d ./ && rm ~/archive.zip

# Копируем скачанный дамп на все пулы
for i in {1..5}; do cp ~/demo-small-20170815.sql /zfs_$i; done

# Посмотрим что получилось
ll /zfs_*
/zfs_1:
total 22274
drwxr-xr-x  2 root root         3 Sep 28 19:29 ./
drwxr-xr-x 29 root root      4096 Sep 28 19:24 ../
-rw-r--r--  1 root root 103865532 Sep 28 19:26 demo-small-20170815.sql

/zfs_2:
total 101505
drwxr-xr-x  2 root root         3 Sep 28 19:29 ./
drwxr-xr-x 29 root root      4096 Sep 28 19:24 ../
-rw-r--r--  1 root root 103865532 Sep 28 19:26 demo-small-20170815.sql

/zfs_3:
total 39497
drwxr-xr-x  2 root root         3 Sep 28 19:29 ./
drwxr-xr-x 29 root root      4096 Sep 28 19:24 ../
-rw-r--r--  1 root root 103865532 Sep 28 19:26 demo-small-20170815.sql

/zfs_4:
total 38259
drwxr-xr-x  2 root root         3 Sep 28 19:29 ./
drwxr-xr-x 29 root root      4096 Sep 28 19:24 ../
-rw-r--r--  1 root root 103865532 Sep 28 19:26 demo-small-20170815.sql

/zfs_5:
total 22178
drwxr-xr-x  2 root root         3 Sep 28 19:29 ./
drwxr-xr-x 29 root root      4096 Sep 28 19:24 ../
-rw-r--r--  1 root root 103865532 Sep 28 19:26 demo-small-20170815.sql

# Лидер по сжатию пул zfs_5 с алгоритмом zstd, его преследует zfs_1 с алгоритмом gzip
zfs list
NAME    USED  AVAIL  REFER  MOUNTPOINT
zfs_1  21.9M   810M  21.8M  /zfs_1
zfs_2  99.3M   733M  99.1M  /zfs_2
zfs_3  38.8M   793M  38.6M  /zfs_3
zfs_4  37.6M   794M  37.4M  /zfs_4
zfs_5  21.8M   810M  21.7M  /zfs_5

# Посмотрим степень сжатия
zfs get compressratio
NAME   PROPERTY       VALUE  SOURCE
zfs_1  compressratio  4.55x  -
zfs_2  compressratio  1.00x  -
zfs_3  compressratio  2.57x  -
zfs_4  compressratio  2.65x  -
zfs_5  compressratio  4.57x  -
```

По результатам нашего тестирования с настройками по умолчанию наилучшим алгоритмом по сжатию является zstd, за ним с небольшим отставанием следует gzip.

### 2. Определим настройки пула

```bash
# Скачиваем архив
wget -O archive.tar.gz --no-check-certificate 'https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download'
--2026-09-28 19:47:25--  https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download
Resolving drive.usercontent.google.com (drive.usercontent.google.com)... 142.251.20.132, 2a00:1450:4010:c0f::84
Connecting to drive.usercontent.google.com (drive.usercontent.google.com)|142.251.20.132|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 7275140 (6.9M) [application/octet-stream]
Saving to: ‘archive.tar.gz’

archive.tar.gz                        100%[=======================================================================>]   6.94M  1.01MB/s    in 6.9s

2026-09-28 19:47:39 (1.01 MB/s) - ‘archive.tar.gz’ saved [7275140/7275140]

# Разархивируем
tar -xzvf archive.tar.gz
zpoolexport/
zpoolexport/filea
zpoolexport/fileb

# Список пулов, доступных для импорта.
zpool import -d ./zpoolexport/
   pool: otus
     id: 6554193320433390805
  state: ONLINE
status: Some supported features are not enabled on the pool.
        (Note that they may be intentionally disabled if the
        'compatibility' property is set.)
 action: The pool can be imported using its name or numeric identifier, though
        some features will not be available without an explicit 'zpool upgrade'.
 config:

        otus                         ONLINE
          mirror-0                   ONLINE
            /root/zpoolexport/filea  ONLINE
            /root/zpoolexport/fileb  ONLINE
# Папка ./zpoolexport/ содержит пул otus, сконфигурированный в RAID 1 и состоящий из filea и fileb

# Импортируем данный пул с сохранением названия
zpool import -d ./zpoolexport/ otus 

# Список пулов
zpool list
NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
otus    480M  2.09M   478M        -         -     0%     0%  1.00x    ONLINE  -
zfs_1   960M  21.9M   938M        -         -     0%     2%  1.00x    ONLINE  -
zfs_2   960M  99.3M   861M        -         -     0%    10%  1.00x    ONLINE  -
zfs_3   960M  38.8M   921M        -         -     0%     4%  1.00x    ONLINE  -
zfs_4   960M  37.6M   922M        -         -     0%     3%  1.00x    ONLINE  -
zfs_5   960M  21.8M   938M        -         -     0%     2%  1.00x    ONLINE  -

# Состояние пула otus
zpool status otus
  pool: otus
 state: ONLINE
status: Some supported and requested features are not enabled on the pool.
        The pool can still be used, but some features are unavailable.
action: Enable all features using 'zpool upgrade'. Once this is done,
        the pool may no longer be accessible by software that does not support
        the features. See zpool-features(7) for details.
config:

        NAME                         STATE     READ WRITE CKSUM
        otus                         ONLINE       0     0     0
          mirror-0                   ONLINE       0     0     0
            /root/zpoolexport/filea  ONLINE       0     0     0
            /root/zpoolexport/fileb  ONLINE       0     0     0

errors: No known data errors

# Определим параметры пула otus: размер хранилища; тип pool; значение recordsize; какое сжатие используется; какая контрольная сумма используется.
zfs get available,readonly,recordsize,compression,checksum otus
NAME  PROPERTY     VALUE           SOURCE
otus  available    350M            -
otus  readonly     off             default
otus  recordsize   128K            local
otus  compression  zle             local
otus  checksum     sha256          local
```

### 3. Работа со снапшотами

```bash
# Скачаем файл, указанный в задании:
wget -O otus_task2.file --no-check-certificate 'https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI&export=download'
--2026-09-29 11:43:54--  https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI&export=download
Resolving drive.usercontent.google.com (drive.usercontent.google.com)... 142.251.13.132, 2a00:1450:4001:c1f::84
Connecting to drive.usercontent.google.com (drive.usercontent.google.com)|142.251.13.132|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 5432736 (5.2M) [application/octet-stream]
Saving to: ‘otus_task2.file’

otus_task2.file                     100%[================================================================>]   5.18M  2.63MB/s    in 2.0s

2026-09-29 11:43:59 (2.63 MB/s) - ‘otus_task2.file’ saved [5432736/5432736]

# Восстановим файловую систему из снэпшота
zfs list
NAME             USED  AVAIL  REFER  MOUNTPOINT
otus            2.05M   350M    24K  /otus
otus/hometask2  1.88M   350M  1.88M  /otus/hometask2
zfs_1           21.9M   810M  21.8M  /zfs_1
zfs_2           99.3M   733M  99.1M  /zfs_2
zfs_3           38.8M   793M  38.6M  /zfs_3
zfs_4           37.6M   794M  37.4M  /zfs_4
zfs_5           21.8M   810M  21.7M  /zfs_5

zfs receive otus/test@today < otus_task2.file

zfs list
NAME             USED  AVAIL  REFER  MOUNTPOINT
otus            4.91M   347M    24K  /otus
otus/hometask2  1.88M   347M  1.88M  /otus/hometask2
otus/test       2.83M   347M  2.83M  /otus/test
zfs_1           21.9M   810M  21.8M  /zfs_1
zfs_2           99.3M   733M  99.1M  /zfs_2
zfs_3           38.8M   793M  38.6M  /zfs_3
zfs_4           37.6M   794M  37.4M  /zfs_4
zfs_5           21.8M   810M  21.7M  /zfs_5

# Найдем зашифрованное сообщение в файле secret_message
find /otus/test -name "secret_message" -exec cat {} +
https://otus.ru/lessons/linux-hl/

```

