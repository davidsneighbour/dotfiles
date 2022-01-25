https://i3wm.org/docs/layout-saving.html
https://i3wm.org/docs/
https://github.com/TiagoDanin/Awesome-Polybar



# In your i3 configuration file, you can autostart i3-msg like this:
# (Note that those lines will quickly become long, so typically you would store
#  them in a script with proper indentation.)
exec --no-startup-id "i3-msg 'workspace 0; append_layout ${HOME}/.config/.i3/workspaces/workspace-1.json'"
exec --no-startup-id "i3-msg 'workspace 1; append_layout ${HOME}/.config/.i3/workspaces/workspace-2.json'"
exec --no-startup-id "i3-msg 'workspace 2; append_layout ${HOME}/.config/.i3/workspaces/workspace-3.json'"
exec --no-startup-id "i3-msg 'workspace 3; append_layout ${HOME}/.config/.i3/workspaces/workspace-4.json'"
exec --no-startup-id "i3-msg 'workspace 4; append_layout ${HOME}/.config/.i3/workspaces/workspace-5.json'"
exec --no-startup-id "i3-msg 'workspace 5; append_layout ${HOME}/.config/.i3/workspaces/workspace-6.json'"
exec --no-startup-id "i3-msg 'workspace 6; append_layout ${HOME}/.config/.i3/workspaces/workspace-7.json'"
exec --no-startup-id "i3-msg 'workspace 7; append_layout ${HOME}/.config/.i3/workspaces/workspace-8.json'"
exec --no-startup-id "i3-msg 'workspace 8; append_layout ${HOME}/.config/.i3/workspaces/workspace-9.json'"
exec --no-startup-id "i3-msg 'workspace 9; append_layout ${HOME}/.config/.i3/workspaces/workspace-10.json'"



https://github.com/polybar/polybar-scripts/tree/master/polybar-scripts/popup-calendar
https://github.com/polybar/polybar-scripts/tree/master/polybar-scripts/isrunning-dropbox
https://github.com/meelkor/polybar-i3-windows
https://github.com/crabvk/polybar-gmail




# Keyboard Layout

## Basics

MOD + Enter	open new terminal
MOD + j	focus left
MOD + k	focus down
MOD + l	focus up
MOD + ;	focus right
MOD + a	focus parent
MOD + Space	toggle focus mode

## Moving windows

MOD + Shift + j	move window left
MOD + Shift + k	move window down
MOD + Shift + l	move window up
MOD + Shift + ;	move window right

## Modifying windows

MOD + f	toggle fullscreen
MOD + v	split a window vertically
MOD + h	split a window horizontally
MOD + r	resize mode

## Changing the container layout

MOD + e	default
MOD + s	stacking
MOD + w	tabbed

## Floating

MOD + Shift + Space	toggle floating
MOD + Left click	drag floating

## Using workspaces

MOD + 0-9	switch to another workspace
MOD + Shift + 0-9	move a window to another workspace

## Opening applications / Closing windows

MOD + d	open application launcher (dmenu)
MOD + Shift + q	kill a window

## Restart / Exit

MOD + Shift + c	reload the configuration file
MOD + Shift + r	restart i3 inplace
MOD + Shift + e	exit i3

# Links

- https://www.nerdfonts.com/#home
- https://github.com/Jvanrhijn/polybar-spotify

# layout saving

i3-save-tree --workspace 1 > ~/.config/i3/workspaces/workspace-1.json
