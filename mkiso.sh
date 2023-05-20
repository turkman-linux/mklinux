#!/bin/bash
set -ex
if [[ "$UID" != "0" ]] ; then
    echo "You must be root!"
    exit 31
fi
umask 022
mkdir isowork/live -p
mkdir isowork/boot/grub -p
if ! which ympstrap >/dev/null ; then
    wget https://gitlab.com/turkman/devel/sources/ymp/-/raw/master/scripts/ympstrap -O /bin/ympstrap
    chmod +x /bin/ympstrap
fi
ympstrap rootfs live-boot linux openrc
ln -s openrc-init rootfs/sbin/init || true
ln -s agetty rootfs/etc/init.d/agetty.tty1 || true
chroot rootfs rc-update add agetty.tty1
echo -e "31\n31\n" | chroot rootfs passwd
echo "nameserver 1.1.1.1" > rootfs/etc/resolv.conf
for dir in dev sys proc run tmp ; do
    mount --bind /$dir rootfs/$dir
done
if [[ -f custom ]] ; then
    cp custom rootfs/tmp/custom
    chroot rootfs bash -ex /tmp/custom
    rm rootfs/tmp/custom
fi
for dir in dev sys proc run tmp ; do
    while umount -lf -R rootfs/$dir ; do : ; done
done
# linux-firmware (optional)
if [[ "FIRMWARE" != "" ]] ; then
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
mksquashfs rootfs isowork/live/filesystem.squashfs -comp gzip -wildcards
install rootfs/boot/vmlinuz-* isowork/linux
install rootfs/boot/initrd.img-* isowork/initrd.img
cat > isowork/boot/grub/grub.cfg <<EOF
insmod all_video
menuentry TurkMan {
    linux /linux boot=live quiet
    initrd /initrd.img
}
EOF
grub-mkrescue -o turkman.iso isowork
