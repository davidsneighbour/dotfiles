# Argon NEO 5

## Setup software

```bash
sudo apt install xrdp openssh-server
```

After that run `sudo raspi-config` and enable *SSH* under *Interfaces*.

## Setup NVMe EB extension

```bash
curl https://download.argon40.com/argon-eeprom.sh | bash
```

Reboot the Pi.

It will boot now from NVMe. That means that if it has a new Raspberry Pi image on it the whole installation and setup shebang will have to be done again. Do not install updates, do not remove unused browser to get through this as fast as possible (and set it up later).

Reminder: If you are using a MelGeek Modern 97 Keyboard the Bluetooth connection might fail and we need to set it to "device 2" or another device not used previously on the RaspberryPi. This is done via FN/Option key and then a digit from 1 to 6.

Reminder 2: The SDCard could now be removed and used elsewhere.

Next install the Argon Neo 5 setup:

```bash
curl https://download.argon40.com/argonneo5.sh | bash
```
