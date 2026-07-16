# BareMetal RAM Dumper

<img width="4320" height="2032" alt="image" src="https://github.com/user-attachments/assets/02aa51f9-ad96-4443-91e8-8b645f086e12" />


A simple x86 bare-metal tool designed to boot from a disk/USB and dump the system's RAM directly to the booting medium. It relies on BIOS interrupts to boot and perform disk operations, and enters unreal mode to access memory above the 1MB barrier.

## Background: Cold Boot Attacks ❄️
This tool was originally developed and successfully tested for experimenting with **Cold Boot Attacks**. By freezing a laptop's RAM (down to -60°C) and quickly rebooting from a USB drive containing this tool, it is possible to dump the frozen memory contents to the disk before the data decays, allowing for the extraction of sensitive information like encryption keys.

## Features
- **Custom Bootloader:** Boots directly from the BIOS (Legacy CSM). No OS required.
- **Unreal Mode:** Switches temporarily to unreal mode to access and read 32-bit physical memory addresses.
- **Memory Map parsing:** Uses BIOS `INT 0x15 E820` to detect valid RAM regions and avoid dumping reserved memory or memory-mapped I/O.
- **Direct Disk Write:** Uses BIOS `INT 0x13 AH=0x43` (Extended Write) to write the memory contents directly back to the boot drive starting at LBA 64.

## How it Works
1. `stage1.asm` is a 512-byte boot sector. It initializes segment registers, sets up the stack, and uses Extended Read (`INT 0x13 AH=0x42`) to load `stage2` from LBA 1 into memory at `0x8000`. Then it jumps to `stage2`.
2. `stage2.asm` performs the main logic:
    - Queries the BIOS for EDD (Enhanced Disk Drive) support.
    - Gets the memory map using `INT 0x15 E820`.
    - Calculates the maximum RAM size.
    - Loops through RAM in 32KB chunks.
    - For each chunk, it switches to unreal mode to copy data from high memory into a low memory buffer (`0x90000`).
    - Writes the 32KB chunk to disk using Extended Write, starting at LBA 64.
    - Prints a progress percentage on the screen.

## Warning ⚠️
**This tool writes raw data directly to the boot drive starting at Sector 64!**
If you write this to a USB drive containing important data, the RAM dump will overwrite whatever is present at LBA 64 and beyond. Use a dedicated, blank USB flash drive for this purpose.

## Building
You will need [NASM](https://www.nasm.us/) installed to compile this project.

On Windows, run the provided build script:
```cmd
build.bat
```
On Linux, you can run:
```bash
nasm -f bin stage1.asm -o stage1.bin
nasm -f bin stage2.asm -o stage2.bin
cat stage1.bin stage2.bin > boot.bin
```

## Usage
1. Build the project to generate `boot.bin`.
2. Write `boot.bin` to a USB drive (e.g. using `dd` on Linux/macOS, or Rufus / Win32DiskImager on Windows).
    - *Note:* Make sure your USB drive has enough space to hold your system's RAM.
    - *Example (Linux):* `sudo dd if=boot.bin of=/dev/sdX bs=512`
3. Boot your target PC from the USB drive (ensure Legacy BIOS / CSM boot is enabled).
4. Wait for the dump to complete (it will show 100%).
