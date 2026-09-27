#! /bin/bash

# Далее выполняем все команды из под рута
sudo -i

# Создаем Physical volume и Volume group с именем "vg_root" на диске sdb
vgcreate vg_root /dev/sdb

# Создаем Logical volume с именем lv_root в группе vg_root
lvcreate -n lv_root -L 8G vg_root

# Форматируем Logical volume lv_root в ext4
mkfs.ext4 /dev/vg_root/lv_root

# Монтируем Logical volume lv_root в /mnt
mount /dev/vg_root/lv_root /mnt

# Копируем все данные из корня / в /mnt
rsync -avxHAX --progress / /mnt/

# Сымитируем текущий root, сделаем в него chroot

# Cвяжем железное окружение текущей машины с новой системой, что позволяет полноценно «войти» в нее и запускать команды так, будто она загружена штатно.
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done

# Выполним смену корневого каталога
 chroot /mnt/

# Автоматически сгенерируем конфигурационный файл для загрузчика GRUB.
grub-mkconfig -o /boot/grub/grub.cfg

# Обновим образ начальной файловой системы (initramfs) для текущего ядра Linux.
update-initramfs -u

# Пробуем перезагрузиться
reboot
Running in chroot, ignoring request.

# Ошибка, т.к. команда reboot была запущена внутри изолированного окружения chroot, а не в основной системе. Из соображений безопасности systemd внутри chroot заблокирован и не может перезагрузить реальное физическое железо компьютера (хост-машину).

# Выходим из chroot в основную систему
exit

# Безопасно размонтируем виртуальные файловые системы хоста
for i in /proc/ /sys/ /dev/ /run/ /boot/; do umount -l /mnt/$i; done

# Перезагружаемся, чтобы работать с новым разделом
reboot

# Посмотрим блочные устройства после перезагрузки и убедимся, что корень перехал на временный
lsblk

# Далее выполняем все команды из под рута
sudo -i

# Т.к. ext4 плохо работает на сжатие, то пересоздадим основной раздел

# Удаляем старый основной раздел
lvremove /dev/ubuntu-vg/ubuntu-lv

# Создаем новый основной раздел с заданным размером 8GB
lvcreate -n ubuntu-lv -L 8G /dev/ubuntu-vg

# С новым основным разделом проделываем все те же манипуляции, что и с временным

# Форматируем Logical volume ubuntu-lv в ext4
mkfs.ext4 /dev/ubuntu-vg/ubuntu-lv

# Монтируем Logical volume ubuntu-lv в /mnt
mount /dev/ubuntu-vg/ubuntu-lv /mnt

# Копируем все данные из корня / в /mnt
rsync -avxHAX --progress / /mnt/

# Сымитируем текущий root, сделаем в него chroot

# Cвяжем железное окружение текущей машины с новой системой, что позволяет полноценно «войти» в нее и запускать команды так, будто она загружена штатно.
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done

# Выполним смену корневого каталога
chroot /mnt/

# Автоматически сгенерируем конфигурационный файл для загрузчика GRUB.
grub-mkconfig -o /boot/grub/grub.cfg

# Обновим образ начальной файловой системы (initramfs) для текущего ядра Linux.
update-initramfs -u

# Пока не вышли из под chroot перенесем /var 
# На свободных дисках создаем зеркало:
# Создаем Physical volume на дисках sdd b sde
pvcreate /dev/sdd /dev/sde

# Создаем Volume group с именем "vg_var" на дисках sdd и sde
vgcreate vg_var /dev/sdd /dev/sde

# Создаем Logical volume c зеркалированием и именем lv_var в группе vg_var 
lvcreate -l+100%FREE -m1 -n lv_var vg_var

# Форматируем Logical volume lv_var в ext4
mkfs.ext4 /dev/vg_var/lv_var

# Монтируем Logical volume lv_var в /mnt
mount /dev/vg_var/lv_var /mnt

# Копируем все данные из /var в /mnt
cp -aR /var/* /mnt/

# Очистим /var c cохранением резервной копии в /tmp/oldvar
mkdir /tmp/oldvar && mv /var/* /tmp/oldvar


# Отмонтируем новый каталог var от /mnt
umount /mnt

# Смонтируем новый каталог var в /var
mount /dev/vg_var/lv_var /var

# Выходим из chroot в основную систему
exit

# Безопасно размонтируем виртуальные файловые системы хоста
for i in /proc/ /sys/ /dev/ /run/ /boot/; do umount -l /mnt/$i; done

# Перезагружаемся
reboot

# Далее выполняем все команды из под рута
sudo -i

# Удалим логический том lv_root
lvremove /dev/vg_root/lv_root

# Удалим группу vg_root
vgremove /dev/vg_root

# Удалим из LVM физический том
pvremove /dev/sdb

# Создадим и отформатируем том под home, затем продмантируем его в /mnt
vgcreate vg_home /dev/sdc
lvcreate -n lv_home -L 1G /dev/vg_home
mkfs.ext4 /dev/vg_home/lv_home
mount /dev/vg_home/lv_home /mnt/

# Скопируем содержимое каталога /home, затем очистим его
cp -aR /home/* /mnt/
rm -rf /home/*

# Отмонтируем новый от /mnt и подмонтируем его в /home
umount /mnt
mount /dev/vg_home/lv_home /home/

# Добавим новый раздел /home в fstab для автоматического монтирования при загрузке
echo "`blkid | grep lv_home | awk '{print $2}'` /home ext4 defaults 0 0" >> /etc/fstab

# Перезагрузимся, чтобы дальше помучиться
reboot

# Генерируем файлы в /home
touch /home/file{1..15}
ls -alF /home

# Снимем снэпшот
lvcreate -L 500MB -s -n home_snap_01 /dev/vg_home/lv_home

# Удалим часть файлов
rm -f /home/file{10..15}
ls -alF /home

# Восстановим удаленные файлы
umount /home

# Проблема в том, что у нас /home подмонтирован через fstab, мы подключились по ssh через пользователя vagrant и файлы в /home заняты
fuser -v /home
lsof /home

# Как только мы попытаемся убить процессы удерщивающие файлы, нас выкинет из сессии
sudo fuser -km /home

# Решение: будем подключаться по ssh под пользователем root, для чего поправим конфиг 
nano /etc/ssh/sshd_config
PermitRootLogin yes
PasswordAuthentication yes

# Перезапустип ssh
systemctl restart ssh

#  Зададим пароль для пользователя root
passwd

# Закроем текущую сессию залогинимся по ssh рутом
# Сначала определим порт через который пробрасывается ssh в виртуалку:  vagrant ssh-config
# Затем поключимся: ssh root@127.0.0.1 -p 2222
# Теперь мы можем спокойно отмонтировать /home, а если кто удерживает файлы, то прибьем процессы и нас не выкинет.
umount /home

# Выполним слияния снимка home_snap_01 с оригинальным томом
lvconvert --merge /dev/vg_home/home_snap_01

# Подмонтируем /home обратно
mount /dev/mapper/vg_home-lv_home /home

# Проверим содержимое /home
ls -alF /home

# Удаленные файлы восстановлены!!!

