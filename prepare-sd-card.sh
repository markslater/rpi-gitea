#!/usr/bin/env bash
set -e

if [[ $# -ne 2 ]]
    then
        echo "Usage ${0} sdCard path-to-ssh-public-key"
        echo "e.g. ${0} /dev/mmcblk0 ~alice/.ssh/id_rsa.pub"
        exit 1
fi

DEVICE_NAME="${1}"
PUBLIC_KEY=`cat "${2}"`

# TODO disable root login
# TODO more recent raspberrypi-ua-netinst
parted --script "${DEVICE_NAME}" mklabel msdos
parted --script --align optimal "${DEVICE_NAME}" mkpart primary fat32 0% 100%
parted --script "${DEVICE_NAME}" set 1 boot on
wget -qO- https://github.com/FooDeas/raspberrypi-ua-netinst/releases/download/v2.1.0/raspberrypi-ua-netinst-v2.1.0.img.xz | xzcat - > "${DEVICE_NAME}"

MOUNT_POINT=`mktemp --directory`

mount -t vfat /dev/mmcblk0p1 "${MOUNT_POINT}"

cat > "${MOUNT_POINT}/raspberrypi-ua-netinst/config/installer-config.txt" <<- EOM
packages="git,mysql-server"

root_ssh_pubkey=""
root_ssh_pwlogin=0
rootpw=

username=pi
usersysgroups="systemd-journal"
user_ssh_pubkey="${PUBLIC_KEY}"
ssh_pwlogin=0

hostname=gitea

timezone=Europe/London
keyboard_layout=gb
locales="en_GB.UTF-8"
system_default_locale="en_GB.UTF-8"
EOM

# TODO verify GPG signature
# TODO set up service
# TODO reduce /etc/gitea permissions 'after configuration'
# TODO later version of gitea
# TODO do we actually need mysql to get started?
cat > "${MOUNT_POINT}/raspberrypi-ua-netinst/config/post-install.txt" <<- EOM
chroot /rootfs adduser \
   --system \
   --shell /bin/bash \
   --gecos 'Git Version Control' \
   --group \
   --disabled-password \
   --home /home/git \
   git

chroot /rootfs mkdir -p /var/lib/gitea/{custom,data,indexers,public,log}
chroot /rootfs chown git:git /var/lib/gitea/{data,indexers,log}
chroot /rootfs chmod 750 /var/lib/gitea/{data,indexers,log}
chroot /rootfs mkdir /etc/gitea
chroot /rootfs chown root:git /etc/gitea
chroot /rootfs chmod 770 /etc/gitea

chroot /rootfs wget --quiet --output-document /usr/local/bin/gitea https://dl.gitea.io/gitea/1.5.3/gitea-1.5.3-linux-arm-6
chroot /rootfs chmod +x /usr/local/bin/gitea
EOM

umount "${MOUNT_POINT}"
rmdir "${MOUNT_POINT}"