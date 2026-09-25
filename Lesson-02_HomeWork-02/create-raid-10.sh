#! /bin/bash

# This script must be run as root
# Input params: 1- number of disks; 2- disk size; 3- device
NUM_DISKS=$1
DISK_SIZE=$2
RAID_DEV=$3

echo "Input params: num_disks: $NUM_DISKS disk_size: $DISK_SIZE raid_dev: $RAID_DEV"

# Find added disks by size and the absence of a mount point
arrDisks=($(lsblk -bdno NAME,SIZE,MOUNTPOINTS | awk -v disk_size="$DISK_SIZE" '$2==disk_size && $3=="" {print "/dev/"$1}' | sort))

# Create disks list
DISKS=""
for ((i=0; i<$NUM_DISKS-1; i++)); do
  DISKS="$DISKS ${arrDisks[$i]}"
done

echo "Found disks: $DISKS"

# Create RAID 10
mdadm --zero-superblock --force $DISKS
mdadm --create $RAID_DEV --bitmap=internal --level=10 --raid-devices=$(( NUM_DISKS - 1 )) $DISKS

# Add spare disk
mdadm $RAID_DEV --add ${arrDisks[$(( NUM_DISKS - 1 ))]}

# So that the array assembled and named correctly
mdadm --detail --scan | tee -a /etc/mdadm/mdadm.conf
#mdadm --detail --scan --verbose | tee -a /etc/mdadm/mdadm.conf
#mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' | tee -a /etc/mdadm/mdadm.conf
# Let's update the initramfs (because the OS reads the disk structure from the initramfs at a very early stage of the boot process)
update-initramfs -u -k all