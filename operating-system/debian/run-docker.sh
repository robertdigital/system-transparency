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
user_name="$1"

if ! id "${user_name}" >/dev/null 2>&1
then
   echo "User ${user_name} does not exist"
   exit 1
fi

kernel="debian-buster-amd64.vmlinuz"
initrd="debian-buster-amd64.cpio.gz"

echo "[INFO]: Build docker image"
echo ""
docker build -t debos "${dir}/docker" || { echo -e "building docker image $failed"; exit 1; }
echo ""
echo "[INFO]: Build Debian OS reproducible via docker container"
echo ""
docker run --cap-add=SYS_ADMIN --privileged -it -v "${root}:/system-transparency/" debos || { echo -e "running docker image $failed"; exit 1; }

chown -c "$user_name" "${dir}/docker/out/${kernel}"
chown -c "$user_name" "${dir}/docker/out/${initrd}"

echo "Kernel and Initramfs generated at: $(realpath --relative-to=${root} "${dir}/docker/out")"

