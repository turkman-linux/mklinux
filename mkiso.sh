#!/bin/bash
if [[ "$UID" != "0" ]] ; then
    echo "You must be root!"
    exit 31
fi
umash 022
mkdir isowork/live -p
mkdir isowork/boot/grub -p
if ! which ympstrap >/dev/null ; then
    wget https://gitlab.com/turkman/devel/sources/ymp/-/raw/master/scripts/ympstrap -O /bin/ympstrap
    chmod +x /bin/ympstrap
fi
ympstrap rootfs live-boot linux openrc bash
echo -e "31\n31\n" | chroot rootfs passwd
echo "nameserver 1.1.1.1" > rootfs/etc/resolv.conf
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
