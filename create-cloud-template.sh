#!/bin/bash
set -e
#set -x
clear
printf "\n*** This script will download a cloud image and create a Proxmox VM template from it. ***\n\n"

### How to use:
### Pre-req:
### - run on a Proxmox 6 server
### - a dhcp server should be active on vmbr1
###
### - fork the gist and adapt the defaults as needed
### - download the script into /usr/local/bin/
### - chmod +x /usr/local/bin/create-cloud-template.sh
### - prepare a cloudinit user-config.yml in the working directory (optional)
### - run the script
### - clone the template from the Proxmox GUI and test
###
### NOTES:
### - links to cloud images:
###   https://docs.openstack.org/image-guide/obtain-images.html
###   Debian http://cdimage.debian.org/cdimage/openstack/
###   Ubuntu http://cloud-images.ubuntu.com/
###   CentOS: http://cloud.centos.org/centos/7/images/
###   Fedora: https://alt.fedoraproject.org/cloud/
###   SUSE 15 SP1 JeOS: https://download.suse.com/Download?buildid=OE-3enq3uys~
###   CirrOS http://download.cirros-cloud.net/
###   CoreOS: https://stable.release.core-os.net/amd64-usr/current/
###   Gentoo: http://gentoo.osuosl.org/experimental/amd64/openstack
###   Arch (also Gentoo): https://linuximages.de/openstack/arch/
###   Alpine: https://github.com/chriswayg/packer-qemu-cloud/
###   RancherOS: https://github.com/rancher/os/releases (also includes Proxmox version)
### - most links will download the latest current (stable) version of the OS
### - older cloud-init versions do not support hashed passwords

printf "* Available templates to generate:\n 2) debian9\n 3) debian10\n 4) ubuntu1804\n 5) centos7\n 6) coreos\n 7) arch\n 8) alpine310\n 9) fedora coreos\n 10) openwrt19\n\n"
read -p "* Enter number of distro to use: " OSNR

# defaults which are used for most templates
RESIZE=+30G
MEMORY=2048
BRIDGE=vmbr0
ENABLE_CLOUD_INIT=true
USERCONFIG_DEFAULT=none # cloud-init-config.yml
CITYPE=nocloud
SNIPPETSPATH=/var/lib/vz/snippets
SSHKEY=~/.ssh/2019_id_rsa.pub # ~/.ssh/id_rsa.pub
CONF_APPEND=""
NOTE=""
RENAME_FILE_EXTENSION=""

case $OSNR in

  2)
    OSNAME=debian9
    VMID_DEFAULT=52000
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    VMIMAGE=debian-9-openstack-amd64.qcow2
    NOTE="\n## Default user is 'debian'\n## NOTE: In Debian 9, setting a password via cloud-config does not seem to work!\n"
    printf "$NOTE\n"
    wget -P /tmp -N https://cdimage.debian.org/cdimage/openstack/current-9/$VMIMAGE
    ;;

  3)
    OSNAME=debian10
    VMID_DEFAULT=53000
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    VMIMAGE_DEFAULT=debian-10.0.3-20190815-openstack-amd64.qcow2
    NOTE="\n## Default user is 'debian'\n"
    printf "$NOTE## NOTE: Check, if the image is up to date on https://cdimage.debian.org/cdimage/openstack/\n\n"
    read -p "Enter the new VM image filename [$VMIMAGE_DEFAULT]: " VMIMAGE
    VMIMAGE=${VMIMAGE:-$VMIMAGE_DEFAULT}
    wget -P /tmp -N https://cdimage.debian.org/cdimage/openstack/current/$VMIMAGE
    ;;

  4)
    OSNAME=ubuntu1804
    VMID_DEFAULT=54000
    NOTE="\n## Default user is 'ubuntu'\n"
    printf "$NOTE\n"
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    VMIMAGE=bionic-server-cloudimg-amd64.img
    wget -P /tmp -N https://cloud-images.ubuntu.com/bionic/current/$VMIMAGE
    ;;

  5)
    OSNAME=centos7
    VMID_DEFAULT=55000
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    RESIZE=+24G
    VMIMAGE=CentOS-7-x86_64-GenericCloud.qcow2
    NOTE="\n## Default user is 'centos'\n## NOTE: CentOS seems to ignore hostname config!\n# use `hostnamectl set-hostname centos7-cloud`\n"
    printf "$NOTE\n"
    wget -P /tmp -N http://cloud.centos.org/centos/7/images/$VMIMAGE
    ;;

  6)
    # - Proxmox creates a configdrive with the option: 'manage_etc_hosts: true'
    # which causes an error in 'user-configdrive.service':
    # 'Failed to apply cloud-config: Invalid option to manage_etc_hosts'
    # there is no problem, when supplying a compatible 'user-config.yml'
    # - coreos needs 'configdrive2'
    # https://github.com/coreos/coreos-cloudinit/blob/master/Documentation/config-drive.md
    OSNAME=coreos
    VMID_DEFAULT=56000
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    RESIZE=+24G
    VMIMAGE=coreos_production_qemu_image.img.bz2
    RENAME_FILE_EXTENSION=qcow2
    CITYPE=configdrive2
    NOTE="\n## Default user is 'core'\n## NOTE: In CoreOS, setting a password via cloud-config does not seem to work!\n"
    printf "$NOTE\n"
    wget -P /tmp -N https://stable.release.core-os.net/amd64-usr/current/$VMIMAGE
    ;;

  7)
    OSNAME=arch
    VMID_DEFAULT=57000
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    RESIZE=+29G
    VMIMAGE=arch-openstack-LATEST-image-bootstrap.qcow2
    NOTE="\n## Default user is 'arch'\n## NOTE: In Arch Linux, setting a password via cloud-config does not seem to work!\n#   - Resizing does not happen automatically inside the VM\n"
    printf "$NOTE\n"
    wget -P /tmp -N https://linuximages.de/openstack/arch/$VMIMAGE
    ;;

  8)
    OSNAME=alpine310
    VMID_DEFAULT=58000
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    VMIMAGE=alpine-310-cloudimg-amd64.qcow2
    NOTE="\n## Default user is 'alpine'\n## NOTE: Cloud-init on Alpine is not yet able to apply network config.\n#  Also setting a password via cloud-config does not seem to work!\n"
    printf "$NOTE\n"
    wget -P /tmp -N https://github.com/chriswayg/packer-qemu-cloud/releases/download/v0.4-beta/$VMIMAGE
    #cp -v /root/$VMIMAGE /tmp/ # for local testing
    ;;

  9)
    OSNAME=fedora-coreos
    DOWNLOAD_URL=`curl -s https://builds.coreos.fedoraproject.org/streams/stable.json| jq --raw-output '.architectures.x86_64.artifacts.qemu.formats["qcow2.xz"].disk.location'`
    VMID_DEFAULT=59000
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    RESIZE=+24G
    VMIMAGE=fedora-coreos-qemu.x86_64.qcow2.xz
    CONF_APPEND="args: -fw_cfg name=opt/com.coreos/config,file=$SNIPPETSPATH/$VMID-$OSNAME.ign"
    NOTE="\n## Default user is 'core'\n## NOTE: In CoreOS, setting a password via cloud-config does not seem to work!\n"
    printf "$NOTE\n"
    wget -O /tmp/$VMIMAGE -N $DOWNLOAD_URL
    SSH_KEY_CONTENT=`cat $SSHKEY`
    printf '{"ignition":{"config":{"replace":{"source":null,"verification":{}}},"security":{"tls":{}},"timeouts":{},"version":"3.0.0"},"passwd":{"users":[{"name":"core","sshAuthorizedKeys":["%s"]}]},"storage":{},"systemd":{}}' "$SSH_KEY_CONTENT" > $SNIPPETSPATH/$VMID-$OSNAME.ign
    ;;

  10)
    OSNAME=openwrt19
    VMID_DEFAULT=60000
    RESIZE=0
    MEMORY=512
    ENABLE_CLOUD_INIT=false
    read -p "Enter a VM ID for $OSNAME [$VMID_DEFAULT]: " VMID
    VMID=${VMID:-$VMID_DEFAULT}
    VMIMAGE=openwrt-19.07.1-x86-64-combined-ext4.img.gz
    NOTE="\n## Default user is 'alpine'\n## NOTE: Cloud-init on Alpine is not yet able to apply network config.\n#  Also setting a password via cloud-config does not seem to work!\n"
    printf "$NOTE\n"
    wget -P /tmp -N https://downloads.openwrt.org/releases/19.07.1/targets/x86/64/$VMIMAGE
    #cp -v /root/$VMIMAGE /tmp/ # for local testing
    ;;

  *)
    printf "\n** Unknown OS number. Please use one of the above!\n"
    exit 0
    ;;
esac

[[ $VMIMAGE == *".bz2" ]] \
    && printf "\n** Uncompressing image (waiting to complete...)\n" \
    && bzip2 -d --force /tmp/$VMIMAGE \
    && VMIMAGE=$(echo "${VMIMAGE%.*}") \

[[ $VMIMAGE == *".xz" ]] \
    && printf "\n** Uncompressing image (waiting to complete...)\n" \
    && unxz -f /tmp/$VMIMAGE \
    && VMIMAGE=$(echo "${VMIMAGE%.*}") \

[[ $VMIMAGE == *".gz" ]] \
    && printf "\n** Uncompressing image (waiting to complete...)\n" \
    && gunzip -f /tmp/$VMIMAGE \
    && VMIMAGE=$(echo "${VMIMAGE%.*}") \

[[ ! -z "$RENAME_FILE_EXTENSION" ]] \
    && mv /tmp/$VMIMAGE /tmp/$VMIMAGE.$RENAME_FILE_EXTENSION \
    && VMIMAGE=$VMIMAGE.$RENAME_FILE_EXTENSION

# TODO: could prompt for the VM name
printf "\n** Creating a VM with $MEMORY MB using network bridge $BRIDGE\n"
qm create $VMID --name $OSNAME-cloud --memory $MEMORY --net0 virtio,bridge=$BRIDGE

printf "\n** Importing the disk in qcow2 format (as 'Unused Disk 0')\n"
qm importdisk $VMID /tmp/$VMIMAGE local-lvm -format qcow2

printf "\n** Attaching the disk to the vm using VirtIO SCSI\n"
qm set $VMID --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-$VMID-disk-0

printf "\n** Setting boot and display settings with serial console\n"
qm set $VMID --boot c --bootdisk scsi0 --serial0 socket --vga serial0

if [ "$ENABLE_CLOUD_INIT" = true ]
then
    printf "\n** Using a dhcp server on $BRIDGE (or change to static IP)\n"
    qm set $VMID --ipconfig0 ip=dhcp
    #This would work in a bridged setup, but a routed setup requires a route to be added in the guest
    #qm set $VMID --ipconfig0 ip=10.10.10.222/24,gw=10.10.10.1

    printf "\n** Creating a cloudinit drive managed by Proxmox\n"
    qm set $VMID --ide2 local-lvm:cloudinit

    printf "\n** Specifying the cloud-init configuration format\n"
    qm set $VMID --citype $CITYPE

    printf "#** Made with create-cloud-template.sh - https://gist.github.com/chriswayg/43fbea910e024cbe608d7dcb12cb8466\n" >> /etc/pve/qemu-server/$VMID.conf
    ## TODO: Also ask for a network configuration. Or create a config with routing for a static IP
    printf "\n*** The script can add a cloud-init configuration with users and SSH keys from a file in the current directory.\n"
    read -p "Supply the name of the cloud-init-config.yml (this will be skipped, if file not found) [$USERCONFIG_DEFAULT]: " USERCONFIG
    USERCONFIG=${USERCONFIG:-$USERCONFIG_DEFAULT}
    if [ -f $PWD/$USERCONFIG ]
    then
        # The cloud-init user config file overrides the user settings done elsewhere
        printf "\n** Adding user configuration\n"
        cp -v $PWD/$USERCONFIG $SNIPPETSPATH/$VMID-$OSNAME-$USERCONFIG
        qm set $VMID --cicustom "user=local:snippets/$VMID-$OSNAME-$USERCONFIG"
        printf "#* cloud-config: $VMID-$OSNAME-$USERCONFIG\n" >> /etc/pve/qemu-server/$VMID.conf
    else
        # The SSH key should be supplied either in the cloud-init config file or here
        printf "\n** Skipping config file, as none was found\n\n** Adding SSH key\n"
        qm set $VMID --sshkey $SSHKEY
        printf "\n"
        read -p "Supply an optional password for the default user (press Enter for none): " PASSWORD
        [ ! -z "$PASSWORD" ] \
            && printf "\n** Adding the password to the config\n" \
            && qm set $VMID --cipassword $PASSWORD \
            && printf "#* a password has been set for the default user\n" >> /etc/pve/qemu-server/$VMID.conf
        printf "#- cloud-config used: via Proxmox\n" >> /etc/pve/qemu-server/$VMID.conf
    fi

    printf "\n*** The following cloud-init configuration for User and Network will be used ***\n\n"
    qm cloudinit dump $VMID user
    printf "\n------------------------------\n"
    qm cloudinit dump $VMID network
fi


# append extra config
printf "$CONF_APPEND\n" >> /etc/pve/qemu-server/$VMID.conf

# The NOTE is added to the Summary section of the VM (TODO there seems to be no 'qm' command for this)
printf "#$NOTE\n" >> /etc/pve/qemu-server/$VMID.conf

printf "\n** Increasing the disk size\n"
qm resize $VMID scsi0 $RESIZE

# convert the vm into a template (TODO make this optional)
qm template $VMID

printf "\n** Removing previously downloaded image file\n\n"
rm -v /tmp/$VMIMAGE

printf "$NOTE\n\n"
