# enable and start
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable excalidraw.service
sudo systemctl start excalidraw.service

# restart after changes
sudo systemctl daemon-reload
sudo systemctl restart excalidraw.service
journalctl -u excalidraw.service -f

# check status
systemctl status excalidraw.service

# logging
journalctl -u excalidraw.service -f
journalctl -u excalidraw.service -n 50 --no-pager
