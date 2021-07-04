# AlmaLinux Raspberry Pi

[![asciicast](https://asciinema.org/a/423618.svg)](https://asciinema.org/a/423618)

Hot on the heels of our aarch64 release a couple of days ago, we've got an image for Raspberry Pi contributed by the immortal [Pablo Greco](https://twitter.com/pablosgreco). I thought I would write up a quick and dirty guide for people to get started with. We'd still like to make a few changes to the image (like having it automatically resize the the rootfs) and those will come, but it's definitely good enough to share, use and gather feedback on. Please file any bugs on https://bugs.almalinux.org and feel free to discuss on our [Community Chat](https://chat.almalinux.org), the [Forums](https://almalinux.discourse.group/t/about-the-raspberry-pi-category/333) or [Reddit](https://www.reddit.com/r/AlmaLinux/).

I tried this all on a Raspberry Pi 4.

**Step 1**: [Grab the image](https://repo.almalinux.org/rpi/images/AlmaLinux-8-aarch64-RaspberryPI-Minimal-4-sda.raw.xz), verify the [CHECKSUM](https://repo.almalinux.org/rpi/images/CHECKSUM) and burn it to an SD card using Fedora Media Writer, Balena, RPi Image, dd or whatever tool you choose.

**Step 2**: Boot. I didn't try to configure wi-fi, but ethernet works for me. I have a PoE hat for my Pi as well so no need for external power.

**Step 3**: Login. The user is `root` password is `almalinux`.

**Step 4**: Since the `rpi-` utilities aren't around yet, it won't resize our rootfs, so we have to do this manually. I have a 128GB SD Card:

1. Go into `parted` and run `print free`. That will give you the partition list and sizes including free space. The rootfs lives on the 3rd partition `/dev/mmcblk0p3`.

2. `resizepart 3` will resize your partition. When it asked for the end I just did 128GB which was from the output of the earlier `print free` command. Make sure to `quit` to save your changes.

3. Run `resize2fs /dev/mmcblk0p3` and then `df -h` and you should now see you have more room to download packages to your hearts content.

**Bonus Round**: Getting GNOME working.
**NOTE**: If you enable GNOME, networking will need to reconfigured. See https://github.com/raspberrypi/linux/issues/4393

[![asciicast](https://asciinema.org/a/423622.svg)](https://asciinema.org/a/423622)

**Step 1**: `dnf groupinstall "Server with GUI"`

**Step 2**: `systemctl set-default graphical`

**Step 3**: `reboot`

**Step 4**: Success!

[![GNOME Desktop on AlmaLinux on Raspberry Pi](https://res.cloudinary.com/marcomontalbano/image/upload/v1625268695/video_to_markdown/images/youtube--HbPRKJrYFbQ-c05b58ac6eb4c4700831b2b3070cd403.jpg)](https://youtu.be/HbPRKJrYFbQ "GNOME Desktop on AlmaLinux on Raspberry Pi")