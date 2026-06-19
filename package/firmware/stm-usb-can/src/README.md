# candleLight_gsusb

This is firmware for certain STM32-based USB-CAN adapters, notably:

This implements the interface of the mainline linux gs_usb kernel module and
works out-of-the-box with linux distros packaging this module, e.g. Ubuntu.

## Known issues

Be aware that there is a bug in the gs_usb module in linux<4.5 that can crash the kernel on device removal.

Here is a fixed version that should also work for older kernels:
  https://github.com/HubertD/socketcan_gs_usb

The Firmware also implements WCID USB descriptors and thus can be used on recent Windows versions without installing a driver.

## Building

Building requires arm-none-eabi-gcc toolchain.

```shell
sudo apt-get install gcc-arm-none-eabi

mkdir build
cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=../cmake/gcc-arm-none-eabi-8-2019-q3-update.cmake

# or,
# cmake-gui ..
# don't forget to specify the cmake toolchain file before configuring.
#
# compile all targets :

make

```


## Flashing

Flashing fw on linux: (source: [https://cantact.io/cantact/users-guide.html](https://cantact.io/cantact/users-guide.html))
- Flashing requires the dfu-util tool.

### recommended simple method
- If compiling with cmake, `make flash-<targetname_fw>`, e.g. `make flash-canable_fw`, to invoke dfu-util.

### method for reflashing a specific device by serial
- when multiple devices are connected, dfu-util may be unable to choose which one to flash.
- Obtain device's serial # by looking at `dfu-util -l`
- adapt the following command accordingly :
 `dfu-util -D CORRECT_FIRMWARE.bin -S "serial_number_here", -a 0 -s 0x08000000:leave`
- note, the `:leave` suffix above may not be supported by older builds of dfu-util and is simply a convenient way to reboot into the normal firmware.

### fail-safe method (or if flashing a blank device)
- Disconnect the USB connector from the CANtact, short the BOOT pins, then reconnect the USB connector. The device should enumerate as "STM32 BOOTLOADER".

- invoke dfu-util manually with: `sudo dfu-util --dfuse-address -d 0483:df11 -c 1 -i 0 -a 0 -s 0x08000000 -D CORRECT_FIRMWARE.bin` where CORRECT_FIRMWARE is the name of the desired .bin.
- Disconnect the USB connector, un-short the BOOT pins, and reconnect.






