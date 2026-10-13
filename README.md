# PMG3000-D20B firmware patcher

## Disclaimer
__Flashing random stuff you found on the Internet can brick your ONT. This script has been tested and the resulting images work for me, but it is in no way a robust piece of software.
There's essentially no error handling or input validation. If you feed it garbage, it will output garbage. Even if the resulting image is valid, things can go wrong while flashing it.
Anything you do with this script is solely your responsibility.__

## Purpose
This script adds an outer header to Zyxel PMG3000-D20B firmware flash dumps (mtd2 / mtd3).
The resulting image can be flashed using the module's web interface (Management | Update Software).  
The updater validates this header, but removes it before writing the image to flash.
That's why raw mtd2 / mtd3 flash dumps don't have this header and can't be flashed using the web interface.

On firmware V1.00(ABVJ.1), the module's SSH server is disabled. If a supported image is detected (currently V1.00(ABVJ.1)b1i and V1.00(ABVJ.1)b1j), the script enables the SSH server by patching the rootfs.

## Usage
```
./mod.sh FILE
```
`FILE` is a raw mtd2 / mtd3 flash dump (3.735.552 bytes).
Flash dumps can be extracted from a running module using SSH or the serial console.
A collection is also available in [this gist](https://gist.github.com/maurice-w/faeb60bf8201ce70391873bcb9059bc2).

## Output
```
firmware.upf      Firmware image with outer header
firmware_ssh.upf  Patched firmware image with outer header (SSH server enabled)
```

## Prerequisites

The script depends on [firmware-mod-kit](https://github.com/rampageX/firmware-mod-kit). An easy way of setting this up is using a Kali Linux container. Kali offers firmware-mod-kit as a package.

```
$ podman pull kali-rolling
$ podman run --tty --interactive kali-rolling

# apt update && apt install -y bsdextrautils dropbear firmware-mod-kit python2 xxd
# ln -s /usr/bin/python2 /usr/bin/python

# git clone https://github.com/maurice-w/pmg3000-d20b-firmware-patcher
# cd pmg3000-d20b-firmware-patcher

# ./patch.sh mtd2.img
```
