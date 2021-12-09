#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Run script with sudo, exiting..."
  exit
fi

KLIPPER_PATH=/home/user/klipper/
PICOTOOL_PATH=/home/user/picotool/build/picotool

#check if picotool is installed
if [ ! -f $PICOTOOL_PATH ]; then
   echo "picotool is not installed, install from https://github.com/raspberrypi/picotool"
   exit
fi  

#pico-sdk and picotool install notes
#git clone -b master https://github.com/raspberrypi/pico-sdk.git
#export PICO_SDK_PATH=~/pico-sdk/
#git clone -b master https://github.com/raspberrypi/picotool.git
#cd picotool/
#mkdir build
#cd build
#cmake ..
#make -j8

#create udev rule for pico and reload udevadm
cat << EOF > /etc/udev/rules.d/99-pico.rules
SUBSYSTEM=="tty", ATTRS{product}=="rp2040",
SYMLINK+="pico"
EOF
udevadm control --reload
echo udev rule for pico added and reloaded

#build pico fw
cd $KLIPPER_PATH
make clean KCONFIG_CONFIG=fw.pico
make menuconfig KCONFIG_CONFIG=fw.pico
make KCONFIG_CONFIG=fw.pico

#find pico
pico=$(udevadm info /dev/ttyACM* | grep -C5 rp2040 | grep DEVNAME | cut -d "=" -f2)
#mount pico fs
stty -F $pico 1200
sleep 5
func_fs () { readlink -f /dev/pico; }
fs=$(func_fs)
echo waiting for fs
while [[ "$fs" != *"1"* ]]; do sleep 0.1; done
mount $fs -t vfat -o x-mount.mkdir /mnt/pico
echo copying firmware to pico
cp $KLIPPER_PATH/out/klipper.uf2 /mnt/pico
echo fw copied to pico, rebooting pico
$PICOTOOL_PATH reboot
sleep 5
#cleanup
umount /mnt/pico; rm -rf /mnt/pico; unset pico; unset fs
