#! /bin/bash

# 1. Find added disks by size and the absence of a mount point
arrDisks=($(lsblk -dno NAME,SIZE,MOUNTPOINTS | awk '$2=="1G" && $3=="" {print "/dev/"$1}' | sort))

# 2. Loop through all found disks
nDisk=0
for D in "${arrDisks[@]}"; do

  nDisk=$(( $nDisk + 1 ))
  #echo "nDisk = $nDisk"

  # 2.1 Format to ext4 (idempotent - check blkid)
  if ! blkid "$D" >/dev/null 2>&1; then
    mkfs.ext4 -F "$D"
  fi

  # 2.2 Mount point
  mkdir -p /mnt/disk"$nDisk"

  # 2.3 Add in fstab by UUID
  DiskUUID=$(blkid -s UUID -o value "$D")
  #echo "DiskUUID = $DiskUUID"
  grep -q "$DiskUUID" /etc/fstab || echo "UUID=$DiskUUID /mnt/disk"$nDisk" ext4 defaults 0 2" >> /etc/fstab

done
