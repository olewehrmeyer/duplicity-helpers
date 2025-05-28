# Duplicity Helpers

A simple backup script template used on my personal servers to

- perform a local backup into a folder
- then back up this folder to Backblaze B2
- and monitor everything via HomeAssistant MQTT

## Requirements

```bash
apt install duplicity python3-b2sdk mosquitto-clients
```

## Install

Place script somewhere, e.g. `/opt/backup` and fill placeholders.

Copy systemd-Files to `/etc/systemd/system`.

Enable and test them with

```bash
systemctl enable duplicity.timer
systemctl start duplicity.timer
systemctl status duplicity.timer
systemctl start duplicity.service
```
