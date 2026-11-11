<!-- markdownlint-disable title-case-style -->
# Custom LightDM greeter configuration

Some quick adaption of the login screen.

* add the lock screen image as background: `setup.sh` copies the image that `dotfiles.session.lockScreenImage` in [`configs/dotfiles.json`](../../dotfiles.json) defines to `/usr/share/backgrounds/login-background.jpg`, the path that `lightdm-gtk-greeter.conf` names. Run `setup.sh` again after the image changes. It works from any directory and asks for `sudo`.
* move login box to the bottom right corner
