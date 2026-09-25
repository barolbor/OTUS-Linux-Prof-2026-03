#! /bin/bash

# This script must be run as root
# Input params: 1- device (default /dev/md0); 2- number of parts (default 5)

if [[ -z "$1" ]]; then
  BLK_DEV=/dev/md0
else
  BLK_DEV=$1
fi

if [[ -z "$2" ]]; then
  PARTS_NUM=5
else
  PARTS_NUM=$2
fi

echo "Input params: blk_dev: $BLK_DEV parts_num: $PARTS_NUM"

# Create new partition GPT table
echo "01 --- do parted mklabel"
parted --script "$BLK_DEV" mklabel gpt

PART_SIZE=$(( 100 / PARTS_NUM ))

echo "part_size: $PART_SIZE"

for ((i=1; i<=PARTS_NUM; i++)); do
  PART_START="$(( (i - 1) * PART_SIZE ))%"
  if [[ "$i" -eq "$PARTS_NUM" ]]; then
    PART_END="100%"
  else
    PART_END="$(( i * PART_SIZE ))%"
  fi
  echo "---> Make part: $i start: $PART_START end: $PART_END"

  # Create pertition
  echo "02 --- do parted mkpart"
  parted -a optimal "$BLK_DEV" mkpart primary ext4 "$PART_START" "$PART_END" --script

  PART_DEV=$BLK_DEV"p"$i

  # Format partition
  echo "03 --- do mkfs.ext4"
  mkfs.ext4 -q "$PART_DEV"

  # Mount partition
  PART_DIR="/mnt/raid"$i

  echo "04 --- do mkdir"
  mkdir -p "$PART_DIR"

  echo "05 --- do mount"
  mount "$PART_DEV" "$PART_DIR"

  # Add to fstab
  PART_UUID=$(blkid -s UUID -o value "$PART_DEV")

  echo "part_dev: $PART_DEV part_dir: $PART_DIR padt_uuid: $PART_UUID"

  echo "06 --- do fstab"
  grep -q "$PART_UUID" /etc/fstab || echo "UUID=$PART_UUID $PART_DIR ext4 defaults 0 2" | tee -a /etc/fstab
done