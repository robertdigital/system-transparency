## Table of Content

| Directory                                                                                                 | Description                                                    |
| --------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| [`/`](../../#scripts)                                                                                     | entry point                                                    |
| [`configs/`](../../configs/#configs)                                                                      | configuration of operating systems                             |
| [`deploy/`](../#deploy)                                                                                   | scripts and files to build firmware binaries                   |
| [`deploy/coreboot-rom/`](../coreboot-rom/#deploy-coreboot-rom)                                            | (work in progress)                                             |
| [`deploy/mixed-firmware/`](#deploy-mixed-firmware)                                                        | disk image solution                                            |
| [`keys/`](../../keys/#keys)                                                                               | example certificates and signing keys                          |
| [`operating-system/`](../../operating-system/#operating-system)                                           | folders including scripts ans files to build reprodu>          |
| [`operating-system/debian/`](../../operating-system/debian/#operating-system-debian)                      | reproducible debian buster                                     |
| [`operating-system/debian/docker/`](../../operating-system/debian/docker/#operating-system-debian-docker) | docker environment                                             |
| [`stboot/`](../../stboot/#stboot)                                                                         | scripts and files to build stboot bootloader from source       |
| [`stboot/include/`](../../stboot/include/#stboot-include)                                                 | fieles to be includes into the bootloader's initramfs          |
| [`stboot/data/`](../../stboot/data/#stboot-data)                                                          | fieles to be placed on a data partition of the host            |
| [`stconfig/`](../../stconfig/#stconfig)                                                                   | scripts and files to build the bootloader's configuration tool |

## Deploy Mixed-Firmware

This deployment solution can be used if no direct control over the host default firmware is given. Since the _stboot_ bootloader uses the _linuxboot_ architecture it consists of a Linux kernel and an initfamfs, which can be treated as a usual operating system. The approach of this solution is to create an image including this kernel and initramfs. Additionally, the image contains an active boot partition with a separate bootloader written to it. _Syslinux_ is used here.

The image can then be written to the host's hard drive. During the boot process of the host's default firmware the _Syslinux_ bootloader is called and hands over control to the \*stboot bootloader finally.

### Scripts

#### `build_kernel.sh`

This script is invoked by 'run.sh'. It downloads and veriifys sours code for Linux kernel version 4.19.6. The kernel is build according to 'x86_64_linuxboot_config' file. This kernel will be used as part of linuxboot. The script writes 'vmlinuz-linuxboot' in this directory.

#### `create_image.sh`

This script is invoked by 'run.sh'. Firstly it creates a raw image, secondly _sfdisk_ is used to write the partitions table. Thirdly the script downloads _Syslinux_ bootloader and installs it to the Master Boot Record and the Partition Boot Record respectively. Finally, the _linuxboot_ kernel 'vmlinuz-linuxboot' is copied to the image. The output is 'MBR_Syslinux_Linuxboot.img'.

Notice that the image is incomplete at this state. The appropriate initramfs need to be included.

#### `mount_boot.sh`

This script is for custom use. If you want to inspect or modify files of the boot partition (1st partition) of 'Syslinux_Linuxboot.img' use this script. It mounts the image via a loop device at a temporary directory. The path is printed to the console.

#### `mount_data.sh`

This script is for custom use. If you want to inspect or modify files of the data partition (2nd partition) of 'Syslinux_Linuxboot.img' use this script. It mounts the image via a loop device at a temporary directory. The path is printed to the console.

#### `mv_hostvars_to_image.sh`

Optional at the moment. This Script copies the 'hostvars.json' configuration file to the image.

#### `mv_initrd_to_image.sh`

this script is invoked by 'run.sh'. It copies the linuxboot initramfs including _stboot_ to the image.

#### `umount_boot.sh`

Counterpart of 'mount_boot.sh'.

#### `umount_data.sh`

Counterpart of 'mount_data.sh'.

### Configuration Files

#### `gpt.table`

This files describes the partition layout of the image

#### `syslinux.cfg`

This is the configuration file for _Syslinux_. The paths for kernel and initramfs are set here. Further the kernel command line can be adjusted to controll the behavior of stboot as well. The default looks like this:
```
DEFAULT linuxboot

LABEL linuxboot
	KERNEL ../vmlinuz-linuxboot
	APPEND console=ttyS0,115200 uroot.uinitargs="-debug"
	INITRD ../initramfs-linuxboot.cpio.gz
```
To controll the output of stboot there are the following options for the kernel command line:

* print output to multiple consoles: `console=tty0 console=ttyS0,115200 printk.devkmsg=on uroot.uinitargs="-debug -klog"` (input is still taken from the last console defined. Furthermore it can happen that certain messages are only displayed on the last console)

* print minimal output: `console=ttyS0,115200`


#### `x86_64_linuxboot_config`

This is the kernel config for the _linuxboot_ kernel. In addition to x86_64 based _defconfig_ the following is set:

```
Processor type and features  --->
    [*] Linux guest support --->
        [*] Enable Paravirtualization code
        [*] KVM Guest support (including kvmclock)
        [*] kexec file based system call
        [*] kexec jump

Device Drivers  --->
    Virtio drivers  --->
        <*> PCI driver for virtio devices
    [*] Block devices  --->
        <*> Virtio block driver
        [*]     SCSI passthrough request for the Virtio block driver
    Character devices  --->
        <*> Hardware Random Number Generator Core support  --->
            <*>   VirtIO Random Number Generator support
```
