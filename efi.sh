#!/usr/bin/bash

# To be called through make

case "$1" in
    delete)
        efibootmgr -q -b $EFI_BOOTNUM -B
        ;;
    add)
        echo -n "\\$EFI_UKI_FILE quiet boot=$(awk '/ \/boot / {print $1}' /etc/fstab) rd.systemd.gpt_auto=0" \
            | iconv -f UTF8 -t UCS-2LE \
            | efibootmgr -b $EFI_BOOTNUM -C -d /dev/vda -p 1 -L $EFI_LABEL -l $EFI_LOADER -@ - -n $EFI_BOOTNUM
        ;;
    *)
        efibootmgr
        ;;
esac
