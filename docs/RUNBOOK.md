# Runbook

This page covers routine operational checks and first-response actions.

## Disk health

Physical hosts expose SMART data through the Prometheus smartctl exporter on port 9633. `smartd` automatically detects local devices and records SMART health.

### Check a device

```bash
sudo smartctl -a /dev/sda
sudo smartctl -a /dev/nvme0
```

Focus on:

- Overall SMART health.
- Reallocated sector count.
- Current pending sector count.
- Media and wear indicators.
- Temperature.

### Respond to alerts

| Alert | First response |
|---|---|
| `SmartHealthFailed` | Confirm backups are current, identify the affected device, avoid writing new important data to it, and schedule replacement. |
| `DiskTemperatureHigh` | Check fans, airflow, dust, and drive spacing. Confirm the temperature falls after corrective action. |
| `DiskTemperatureCritical` | Treat cooling as an immediate issue. Shut down nonessential load if necessary and inspect fans or airflow. |
| `DiskReallocatedSectors` | Record the count and watch its trend. A rising count means plan replacement. |
| `DiskPendingSectors` | Run a non-destructive SMART test, verify backups, and replace the drive if pending sectors persist or increase. |

### Non-destructive test

For SATA/SAS disks:

```bash
sudo smartctl -t short /dev/sda
sudo smartctl -a /dev/sda
```

For NVMe devices:

```bash
sudo smartctl -a /dev/nvme0
```

Do not run destructive tests on a disk containing needed data. Before physically replacing a disk, confirm pool redundancy, current backups, and the replacement disk’s compatibility.
