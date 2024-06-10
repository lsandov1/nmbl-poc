# nmbl proof of concept

This is intended as a proof of concept for nmbl.

# what's here so far

| file | description |
|--|--|
| `99grub2-emu` | grub2-emu plugin for dracut |
| `99grub2-emu/grub2-emu.service` | systemd service to run our grub menu |
| `99grub2-emu/grub2-emu.target` | systemd target to run our services |
| `99grub2-emu/grub2-mount-boot.sh` | helper to mount /boot inside the running initramfs |
| `99grub2-emu/module-setup.sh` | dracut module setup program |
| `etc/dracut-grub2.conf.d/grub2-emu.conf` | dracut configuration to use this plugin |
| `etc/dracut.conf.d/grub2-emu.conf` | default dracut configuration to ignore this plugin |
| `scripts/extract_initrd.sh` | simple (too simple) script to unpack an initramfs |
| `scripts/generate_initrd.sh` | simple script to generate an initramfs |
| `kernel patches/sig-bound-v2` | kernel patch series to fix signature size rules |

# testing - work in progress - the easy way:


## install dependencies
```bash
./deps.sh
```
and reboot your system

## build the rpm:
```bash
make clean && make
```

## install that rpm on the machine
```bash
make install
```

## make a new efibootmgr entry
```bash
make install_efi_entry
```

You should see something like this

```shell
BootNext: 0010
BootCurrent: 0001
Timeout: 3 seconds
BootOrder: 0001,0002,0000
Boot0000* UiApp	FvVol(7cb8bdc9-f8eb-4f34-aaea-3ee4af6516a1)/FvFile(462caa21-7614-4503-836e-8ab6f4662331)
Boot0001* Fedora	HD(1,GPT,b07d79a9-b628-466c-96f6-69e8f7ffbec1,0x800,0x12c000)/File(\EFI\fedora\shimx64.efi)
Boot0002* UEFI Misc Device	PciRoot(0x0)/Pci(0x1,0x3)/Pci(0x0,0x0){auto_created_boot_option}
Boot0010* nmbl	HD(1,GPT,b07d79a9-b628-466c-96f6-69e8f7ffbec1,0x800,0x12c000)/File(\EFI\fedora\shimx64.efi) File(.\nnmbl-cloud.uki quiet boot= rd.systemd.gpt_auto=0)
```

# the old way that's basically the same thing

## install fedora38
Use UEFI, with /boot on its own partition.
  ```bash
  dnf install -y pesign mokutil keyutils rsync git emacs-nox dracut-network grub2-emu binutils systemd-ukify systemd-boot-unsigned systemd-networkd kexec-tools btrfs-progs lvm2
  ```

## provision signing
```bash
efikeygen -d /etc/pki/pesign -S -k -c 'CN=Your Name Key' -n 'Custom Secureboot'
certutil -d /etc/pki/pesign -n 'Custom Secureboot' -Lr > sb_cert.cer
mokutil --import sb_cert.cer
reboot # and enroll key
```

## build a custom kernel
(or skip and use http://ihatethathostname.lab.bos.redhat.com/~rharwood/nmbl/ )

- apply kernel patches from repo dir
- sign it with the key from above
  - I install it and then sign vmlinuz in place

## load in this repo
```bash
mkdir /etc/dracut-grub2.conf.d/
rsync -avP --del 99grub2-emu/ /usr/lib/dracut/modules.d/99grub2-emu/
cp etc/dracut-grub2.conf.d/grub2-emu.conf /etc/dracut-grub2.conf.d/
cp etc/dracut.conf.d/grub2-emu.conf /etc/dracut.conf.d/
```

## ukify
```bash
dracut --verbose --confdir /etc/dracut-grub2.conf.d/ --no-hostonly ./nmbl.uki 6.3.0-0.rc2.89f5349e0673.24.test.fc38.x86_64 --uefi --xz
pesign -s -c 'Custom Secureboot' -i nmbl.uki -o nmbl.uki.signed
```

## install the uki
```bash
cp nmbl.uki.signed /boot/efi/EFI/fedora/nmbl.uki
```

## make a new efibootmgr entry
```bash
efibootmgr -q -b 0010 -B ;
echo -n "\nmbl.uki quiet $(./scripts/guess_rootfs.sh) boot=$(awk '/ \/boot / {print $1}' /etc/fstab) rd.systemd.gpt_auto=0" \
| iconv -f UTF8 -t UCS-2LE \
| efibootmgr -b 0010 -C -d /dev/vda -p 1 -L nmbl -l /EFI/fedora/shimx64.efi -@ - -n 0010
```
