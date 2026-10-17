#!/bin/bash

# FIRMWARE_IN is a raw mtd2 / mtd3 flash dump (3.735.552 bytes)
FIRMWARE_IN=$1
FIRMWARE_OUT="firmware.upf"
FIRMWARE_OUT_SSH="firmware_ssh.upf"
FMK_DIR="/opt/firmware-mod-kit/trunk"
FMK_EXTRACT="${FMK_DIR}/extract-firmware.sh"
FMK_BUILD="${FMK_DIR}/build-firmware.sh"
CRC32="${FMK_DIR}/src/crcalc/crc32"

# Converts hexadecimal CRC32 value into 4 raw bytes (little-endian or big-endian)
function byte_hex2bin {
    v=$(printf "%08x" "0x$1")
    if [ $2 -eq 1 ]; then
        echo "\x${v:6:2}\x${v:4:2}\x${v:2:2}\x${v:0:2}"
    else
        echo "\x${v:0:2}\x${v:2:2}\x${v:4:2}\x${v:6:2}"
    fi
}

# Calculates checksum of $4 bytes of file $5 (starting at offset $3) and writes it to offset $1
function firmware_crc {
    dd if=/dev/zero of="$5" bs=1 seek=$1 count=4 conv=notrunc
    crc=`$CRC32 "$5" $3 $4 | tail -n 1 | awk '{print $2}' | sed "s/0x//1"`
    crc=$(byte_hex2bin $crc $2)
    echo -e "${crc}" | dd of="$5" bs=1 seek=$1 count=4 conv=notrunc
}

echo "Cleaning up..."
rm -rf fmk
rm -f "$FIRMWARE_OUT"
rm -f "$FIRMWARE_OUT_SSH"

echo "Adding outer header to image..."
cat header "$FIRMWARE_IN" > "$FIRMWARE_OUT"
echo "Copying firmware version string to outer header..."
dd if="$FIRMWARE_OUT" of="$FIRMWARE_OUT" bs=1 skip=632 seek=124 count=32 conv=notrunc
echo "Writing checksum of image (with outer header) to outer header..."
firmware_crc 104 0 0 3736064 "$FIRMWARE_OUT"

firmware_in_sha256=$(sha256sum "$FIRMWARE_IN" | awk '{print $1}')
case "$firmware_in_sha256" in
    "ae899ff3e9d1bc1cebed3bc1f47f5c0e449884f5f95c03a677a7549ab5555b1c" | "a9299366433813410783c425e4076fb3fbf7afa79e5894a39a442cdc8aa11512")
        echo "V1.00(ABVJ.1)b1i or V1.00(ABVJ.1)b1j detected, enabling Dropbear SSH server..."
        $FMK_EXTRACT "$FIRMWARE_IN"
        cp -a fmk/rootfs/usr/sbin/dropbear fmk/rootfs/usr/local/bin/
        mkdir -m 775 fmk/rootfs/etc/dropbear
        dropbearkey -t rsa -f fmk/rootfs/etc/dropbear/dropbear_rsa_host_key
        chmod 775 fmk/rootfs/etc/dropbear/dropbear_rsa_host_key
        rm fmk/rootfs/etc/dropbear/dropbear_rsa_host_key.pub
        $FMK_BUILD
        echo "Adding outer header to patched image..."
        cat header fmk/new-firmware.bin > "$FIRMWARE_OUT_SSH"
        echo "Copying firmware version string of patched image to outer header..."
        dd if="$FIRMWARE_OUT_SSH" of="$FIRMWARE_OUT_SSH" bs=1 skip=632 seek=124 count=32 conv=notrunc
        echo "Writing checksum of patched image (without headers and last 64 kiB block) to inner header..."
        firmware_crc 540 1 1024 3669504 "$FIRMWARE_OUT_SSH"
        echo "Writing checksum of inner header of patched image to inner header..."
        firmware_crc 544 1 512  512     "$FIRMWARE_OUT_SSH"
        echo "Writing checksum of patched image (with outer header) to outer header..."
        firmware_crc 104 0 0    3736064 "$FIRMWARE_OUT_SSH"
        ;;
    *)
        echo "SSH patch not supported for this image"
        ;;
esac
