# Android emulator

A local Android phone in a Docker container, for testing mobile browsers, websites, and apps. It uses the free [budtmo/docker-android](https://github.com/budtmo/docker-android) image. The container runs only when you start it.

## What it runs

* Android 14 (API 34), `google_apis` x86_64 system image, with KVM acceleration.
* Device profile "Samsung Galaxy S10", the newest profile in the free image. `emulator-override.ini` replaces its screen with the Galaxy S26 screen: 1080×2340 pixels at density 480. Chrome reports a CSS viewport of 360×780 at a device pixel ratio of 3.
* 4 GB RAM, 4 CPU cores, and a 4 GB data partition.
* Chrome 113 from the system image. The image has no Play Store, so Chrome does not update.

The free image stops at Android 14. Android 15 to 17 are only in the paid `docker-android-pro` image.

## Commands

| Command | Effect |
| --- | --- |
| `android-start --viewer scrcpy` | Start the container, wait for the boot, and show the device in a scrcpy window at the right edge of the current workspace. |
| `android-start --viewer scrcpy --layout fullscreen` | Same, but as a fullscreen window. |
| `android-start --viewer web` | Same, but open the noVNC web view in the browser. |
| `android-start --viewer none` | Start the container only. |
| `android-stop --keep-data` | Close the window, shut Android down cleanly, and remove the container. The device data stays. |
| `android-stop --wipe-data` | Same, and delete the device data (factory reset). Asks first; add `--yes` to skip the question. |

Both commands show their help when you run them without options. Both support `--verbose`, `--quiet`, and `--help`. If the container already runs, `android-start` only opens the viewer. Logs go to `~/.logs/android-emulator/`.

The commands are PATH wrappers in `bin/` for [`android-device.sh`](./android-device.sh). You can also use `docker compose up -d` and `docker compose down` in this folder, but then Android is not shut down cleanly, and files written shortly before the stop can be lost.

Times on locutus: the first boot after `--wipe-data` takes about 25 seconds. Later starts take about 10 seconds, because a clean stop saves a quick-boot snapshot. A stop takes about 8 seconds.

## Ports

Both ports listen on `127.0.0.1` only, because neither service has authentication.

* `127.0.0.1:5600`: ADB. The device serial is `127.0.0.1:5600`.
* `127.0.0.1:3080`: noVNC web view, `http://127.0.0.1:3080/?autoconnect=true`.

## Testing websites

Open a URL on the device:

```bash
adb -s 127.0.0.1:5600 shell am start -a android.intent.action.VIEW -d 'https://example.com' com.android.chrome
```

Skip Chrome's first-run screens. The file stays until the next `--wipe-data`:

```bash
adb -s 127.0.0.1:5600 shell 'echo "_ --disable-fre --no-default-browser-check --no-first-run" > /data/local/tmp/chrome-command-line'
adb -s 127.0.0.1:5600 shell am force-stop com.android.chrome
```

Use DevTools on the device's Chrome: open `chrome://inspect/#devices` in Chrome on the desktop. It finds the device through the local ADB server.

Install another browser or an app from an APK file, for example a newer Chrome or Firefox:

```bash
adb -s 127.0.0.1:5600 install path/to/app.apk
```

## Data

Two named Docker volumes hold the device: `android_android-avd` (the AVD disk images and `config.ini`) and `android_android-home` (`/home/androidusr/.android`). Only these folders are persistent. Do not mount all of `/home/androidusr`: it also holds the image's app code, which would then not update with the image.

Docker creates a new volume as `root`, but the emulator runs as `androidusr` (1300:1301). The one-shot `android-volume-init` service sets the owner of the AVD volume before the emulator starts.

The image applies `emulator-override.ini` and the device profile only when it creates the device. After a change to them, run `android-stop --wipe-data`, then start again.

## Window

scrcpy opens a window with the class `scrcpy` and the title `Android emulator`. The phone screen always stays 1080×2340 (CSS viewport 360×780); scrcpy scales it into the window and keeps the aspect ratio.

In i3, `android-start` places the window after it opens:

* `--layout right` (default): tiled at the right edge of the current workspace, full height, and 1/3 of the width. Alone on a workspace, the window fills it.
* `--layout fullscreen`: a fullscreen window.

If the window is already open, `android-start` does not move it. See "Android emulator window" in [`SESSION.md`](../../../SESSION.md) for how the placement works.

## Update

Renovate opens pull requests for new image digests. After an update, the next `android-start` uses the new image. The device data stays.
