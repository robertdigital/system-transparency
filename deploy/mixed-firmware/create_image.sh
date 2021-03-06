#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

if [ "$#" -ne 1 ]
then
   echo "$0 USER"
   exit 1
fi

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

failed="\e[1;5;31mfailed\e[0m"

# Set magic variables for current file & dir
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "${dir}/../../" && pwd)"

img="${dir}/Syslinux_Linuxboot.img"
img_backup="${dir}/Syslinux_Linuxboot.img.backup"
part_table="${dir}/gpt.table"
syslinux_src="https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/"
syslinux_tar="syslinux-6.03.tar.xz"
syslinux_dir="syslinux-6.03"
syslinux_config="${dir}/syslinux.cfg"
lnxbt_kernel="${dir}/vmlinuz-linuxboot"
src="${root}/src/syslinux/"
mnt=$(mktemp -d -t stmnt-XXXXXXXX)

user_name="$1"

if ! id "${user_name}" >/dev/null 2>&1
then
   echo "User ${user_name} does not exist"
   exit 1
fi

if [ -f "${img}" ]; then
    while true; do
       echo "Current image file:"
       ls -l "$(realpath --relative-to=${root} ${img})"
       read -rp "Update? (y/n)" yn
       case $yn in
          [Yy]* ) echo "[INFO]: backup existing image to $(realpath --relative-to=${root} ${img_backup})"; mv "${img}" "${img_backup}"; break;;
          [Nn]* ) exit;;
          * ) echo "Please answer yes or no.";;
       esac
    done 
fi

echo "[INFO]: check for Linuxboot kernel"
bash "${dir}/build_kernel.sh" "${user_name}"

if [ ! -f "${lnxbt_kernel}" ]; then
    echo "$(realpath --relative-to=${root} ${lnxbt_kernel}) not found!"
    echo -e "creating image $failed"; exit 1
else
    echo "Linuxboot kernel: $(realpath --relative-to=${root} ${lnxbt_kernel})"
fi


if [ -d ${src} ]; then 
   echo "[INFO]: Using cached sources in $(realpath --relative-to=${root} ${src})"
else
   echo "[INFO]: Downloading Syslinux Bootloader"
   wget "${syslinux_src}/${syslinux_tar}" -P "${src}" || { echo -e "Download $failed"; exit 1; }
   tar -xf "${src}/${syslinux_tar}" -C "${src}" || { echo -e "Decompression $failed"; exit 1; }
   chown -R "${user_name}" "${src}"
fi


echo "[INFO]: Creating raw image"
dd if=/dev/zero "of=${img}" bs=1M count=20
losetup -f || { echo -e "Finding free loop device $failed"; exit 1; }
dev=$(losetup -f)
losetup "${dev}" "${img}" || { echo -e "Loop device setup $failed"; losetup -d "${dev}"; exit 1; }
sfdisk --no-reread --no-tell-kernel "${dev}" < "${part_table}" || { echo -e "partitioning $failed"; losetup -d "${dev}"; exit 1; }
partprobe -s "${dev}" || { echo -e "partprobe $failed"; losetup -d "${dev}"; exit 1; }
echo "[INFO]: Make VFAT filesystem for boot partition"
mkfs -t vfat "${dev}p1" || { echo -e "Creating filesystem on 1st partition $failed"; losetup -d "${dev}"; exit 1; }
echo "[INFO]: Make EXT4 filesystem for data partition"
mkfs -t ext4 "${dev}p2" || { echo -e "Creating filesystem on 2nd psrtition $failed"; losetup -d "${dev}"; exit 1; }
partprobe -s "${dev}" || { echo -e "partprobe $failed"; losetup -d "${dev}"; exit 1; }
echo "[INFO]: Raw image layout:"
lsblk -o NAME,SIZE,TYPE,PTTYPE,PARTUUID,PARTLABEL,FSTYPE ${dev}

echo ""
echo "[INFO]: Installing Syslinux"
mount "${dev}p1" "${mnt}" || { echo -e "Mounting ${dev}p1 $failed"; losetup -d "${dev}"; exit 1; }
mkdir  "${mnt}/syslinux" || { echo -e "Making Syslinux config directory $failed"; losetup -d "${dev}"; exit 1; }
umount "${mnt}" || { echo -e "Unmounting $failed"; losetup -d "${dev}"; exit 1; }
"${src}/${syslinux_dir}/bios/linux/syslinux" --directory /syslinux/ --install "${dev}p1" || { echo -e "Writing vollume boot record $failed"; losetup -d "${dev}"; exit 1; }
dd bs=440 count=1 conv=notrunc "if=${src}/${syslinux_dir}/bios/mbr/gptmbr.bin" "of=${dev}" || { echo -e "Writing master boot record $failed"; losetup -d "${dev}"; exit 1; }
mount "${dev}p1" "${mnt}" || { echo -e "Mounting ${dev}p1 $failed"; losetup -d "$dev"; exit 1; }
cp "${syslinux_config}" "${mnt}/syslinux"
cp "${lnxbt_kernel}" "${mnt}"
umount "${mnt}" || { echo -e "Unmounting $failed"; losetup -d "$dev"; exit 1; }

echo ""
echo "[INFO]: Moving data files"
mount "${dev}p2" "${mnt}" || { echo -e "Mounting ${dev}p2 $failed"; losetup -d "$dev"; exit 1; }
cp -R "${root}/stboot/data/." "${mnt}" || { echo -e "Copying files $failed"; losetup -d "$dev"; exit 1; }
rm "${mnt}/create_example_data.sh"
rm "${mnt}/README.md"
umount "${mnt}" || { echo -e "Unmounting $failed"; losetup -d "$dev"; exit 1; }

losetup -d "${dev}" || { echo -e "Loop device clean up $failed"; exit 1; }
rm -r -f "${mnt}"
echo ""
chown -c "${user_name}" "${img}"

echo ""
echo "[INFO]: $(realpath --relative-to=${root} ${img}) created."
echo "[INFO]: Linuxboot initramfs needs to be included."

