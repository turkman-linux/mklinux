#!/bin/bash
set -ex
if [[ "$UID" != "0" ]] ; then
    echo "You must be root!"
    exit 31
fi
umask 022
mkdir isowork/live -p
mkdir isowork/boot/grub -p
if [[ "$REPO" == "" ]] ; then
    export REPO='https://gitlab.com/turkman/packages/binary-repo/-/raw/master/$uri'
fi
if ! which ympstrap >/dev/null ; then
    wget https://gitlab.com/turkman/devel/sources/ymp/-/raw/master/scripts/ympstrap -O /bin/ympstrap
    chmod +x /bin/ympstrap
fi
# create rootfs
if [[ ! -f rootfs/etc/os-release ]] ; then
    ympstrap rootfs live-boot linux openrc gnupg kmod initramfs-tools eudev gnupg
fi
# bind mount
for dir in dev sys proc run tmp ; do
    mount --bind /$dir rootfs/$dir
done
# openrc settings
ln -s openrc-init rootfs/sbin/init || true
ln -s agetty rootfs/etc/init.d/agetty.tty1 || true
ln -s agetty rootfs/etc/init.d/agetty.tty2 || true
ln -s agetty rootfs/etc/init.d/agetty.tty3 || true
ln -s agetty rootfs/etc/init.d/agetty.tty4 || true
ln -s agetty rootfs/etc/init.d/agetty.tty5 || true
ln -s agetty rootfs/etc/init.d/agetty.tty6 || true
chroot rootfs rc-update add agetty.tty1
chroot rootfs rc-update add agetty.tty2
chroot rootfs rc-update add agetty.tty3
chroot rootfs rc-update add agetty.tty4
chroot rootfs rc-update add agetty.tty5
chroot rootfs rc-update add agetty.tty6
# enable live-config servive
chroot rootfs rc-update add live-config
# system configuration
echo -e "live\nlive\n" | chroot rootfs passwd
cat /etc/resolv.conf > rootfs/etc/resolv.conf
# add gpg key
chroot rootfs ymp key --add ${REPO/\$uri/ymp-index.yaml.asc} --name=main --allow-oem
# customize
if [[ -f custom ]] ; then
    cp custom rootfs/tmp/custom
    chroot rootfs bash -ex /tmp/custom
    rm rootfs/tmp/custom
elif [[ -d custom ]] ; then
    for file in $(ls custom) ; do
        cp custom/$file rootfs/tmp/custom
        chroot rootfs bash -ex /tmp/custom
        rm rootfs/tmp/custom
    done
fi
# clean
chroot rootfs ymp clean --allow-oem
find rootfs/var/log -type f -exec rm -f {} \;
rm rootfs/etc/resolv.conf
# linux-firmware (optional)
if [[ "$FIRMWARE" != "" ]] ; then
    src_uri="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/refs/"
    tarball=https://git.kernel.org/$(wget -O - ${src_uri} 2>/dev/null | sed "s/.tar.gz'.*/.tar.gz/g;s/.*'//g" | grep "^/pub" | sort -V | tail -n 1)
    version=$(echo $tarball | sed "s/.*-//g;s/\..*//g")
    wget $tarball -O rootfs/tmp/linux-firmware.tar.gz
    cd rootfs/tmp
    tar -xvf linux-firmware.tar.gz
    cd linux-firmware-$version
    ./copy-firmware.sh ../../lib/firmware
    cd ../../..
    rm -rf rootfs/tmp/linux-firmware*
fi
# bind unmount
for dir in dev sys proc run tmp ; do
    while umount -lf -R rootfs/$dir ; do : ; done
done
if [[ "$COMPRESS" == 'gzip' ]] ; then
    gzip=1
elif [[ "$COMPRESS" == 'none' ]] ; then
    : Compress disabled
else
    xz=1
fi
# create squashfs
mksquashfs rootfs isowork/live/filesystem.squashfs  -b 1048576 ${xz:+-comp xz -Xdict-size 100%} ${gzip:+-comp gzip}  -noappend -wildcards
# copy kernel and initramfs
install rootfs/boot/vmlinuz-* isowork/linux
install rootfs/boot/initrd.img-* isowork/initrd.img
# create grub config
cat > isowork/boot/grub/grub.cfg <<EOF
insmod all_video
terminal_output console
terminal_input console
menuentry TurkMan {
    linux /linux boot=live quiet console=tty31
    initrd /initrd.img
}
EOF
# create iso image
grub-mkrescue -o turkman.iso isowork
