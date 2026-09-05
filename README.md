<p align="center"><img src="resources/apple-touch-icon.png"></p>
<h1 align="center">syslog-flow</h1>

<p align="center"><b>A lightweight syslog server with plain-text storage and a clean, responsive web UI.</b>
</p>

<p align="center"> Send syslogs from your routers, switches, firewalls, NASes, or Linux servers and watch them live in your browser, or browse historical logs from disk using the intuitive sidebar. Plain-text logs. No database, Grafana, Kubernetes, or Elasticsearch.
</p>

![banner](banner.png)

I had always noticed "Remote Syslog" options on various devices. When I learned about how it worked, I was looking forward to setting it up, as it makes troubleshooting failures and real time visibility much easier. However, when I explored the available options, I was shocked to see how overly complicated they were. I just wanted somewhere to send and store logs, with a clean interface to read them. So I created syslog-flow - a Docker container that is simple, self contained, and only has 1 dependency.

<details>
<summary>Actual repository size (without marketing assets)</summary>

```text
4	syslog-flow/Dockerfile
4	syslog-flow/cmd/syslog-flow/cache_test.go
4	syslog-flow/cmd/syslog-flow/logviewer.go
4	syslog-flow/cmd/syslog-flow/main_test.go
4	syslog-flow/cmd/syslog-flow/settings_test.go
4	syslog-flow/docker-compose.yml
4	syslog-flow/entrypoint.sh
4	syslog-flow/go.mod
4	syslog-flow/rsyslog.conf
8	syslog-flow/cmd/syslog-flow/cache.go
8	syslog-flow/cmd/syslog-flow/config_generator.go
16	syslog-flow/cmd/syslog-flow/index.go
20	syslog-flow/cmd/syslog-flow/settings.go
36	syslog-flow/cmd/syslog-flow/main.go
52	syslog-flow/cmd/syslog-flow/web.go
160	syslog-flow/cmd/syslog-flow
164	syslog-flow/cmd
188	syslog-flow
```

</details>

The `syslog-flow` container runs two processes:

- `rsyslogd` listens for syslog on UDP and TCP `514`
- `syslog-flow` serves the web UI and stats API on `2200`

![banner](banner-2.png)

----

## What It Does

- Ingests logs using rsyslog for reliable parsing
- Shows a live-updating log view in the browser
- Stores ingested logs as plain text under `./logs` with logical folder organization.
- Supports day views, per-device views, global search, and severity filters
- Shows simple statistics and live device activity at '/statistics`
- Exposes a simple numeric stats API at `GET /api/stats`
- Caches key information in per-day JSON files for super fast startup and responsive API

Example log layout on-disk:

```text
logs/
  2026/
    05/
      01/
        router.log
        nas.log
        homeassistant.log
        2026-05-01.json
```

## Build and Install

Find a good, logical location for the log storage, then run:

```shell
git clone https://github.com/inventor7777/syslog-flow
cd syslog-flow
```

Then, simply build and run the container:

```shell
docker compose up --build -d
```

Then, start right away by pointing devices at the server IP on syslog UDP/TCP port `514`, and then navigate to `<SERVER-IP:2200>` to view the logs in real time.

Default ports:

- `2200/tcp`: **web UI** and stats API 
- `514/udp`: syslog ingest
- `514/tcp`: syslog ingest

## Bare-metal / systemd Install

If you'd rather not use Docker, `syslog-flow` can run directly on a host with `rsyslog` and be supervised by `systemd`. Debian/Ubuntu users can use the prebuilt `.deb` package (see below); everyone else can use a prebuilt static binary from the [Releases](https://github.com/inventor7777/syslog-flow/releases) page (or one you build yourself with `go build ./cmd/syslog-flow`).

By default, `syslog-flow` follows standard Unix service conventions:

- Logs: `/var/log/syslog-flow` (override with `-log-dir` or `SYSLOG_FLOW_LOG_DIR`)
- Config (`app.json`, `*-colors.json`): `/etc/syslog-flow` (override with `-config-dir` or `SYSLOG_FLOW_CONFIG_DIR`)
- Static assets (`favicon.ico`, `apple-touch-icon.png`): `/usr/local/share/syslog-flow` (override with `-resources-dir` or `SYSLOG_FLOW_RESOURCES_DIR`)

The log and config directories are created automatically on startup if missing; the resources directory must exist and contain the asset files.

### Option A: Debian/Ubuntu package

Each release publishes a `syslog-flow_<version>_<amd64|arm64|armhf>.deb`. It installs the binary to `/usr/bin/syslog-flow`, static assets to `/usr/share/syslog-flow`, the systemd unit to `/lib/systemd/system/syslog-flow.service`, a `syslog-flow` system user, and creates `/var/log/syslog-flow` and `/etc/syslog-flow`:

```bash
curl -LO https://github.com/inventor7777/syslog-flow/releases/download/<TAG>/syslog-flow_<TAG>_amd64.deb
sudo apt install ./syslog-flow_<TAG>_amd64.deb
```

Then wire up rsyslog and enable the service as in steps 2-3 below (the example rsyslog config ships at `/usr/share/doc/syslog-flow/examples/60-syslog-flow.conf`, and the unit is already installed, just not enabled by default).

### Option B: Manual binary install

1. Install the binary, static assets, and required directories:

   ```bash
   sudo install -m 755 syslog-flow /usr/local/bin/syslog-flow
   sudo mkdir -p /var/log/syslog-flow /etc/syslog-flow /usr/local/share/syslog-flow
   sudo install -m 644 resources/favicon.ico resources/apple-touch-icon.png /usr/local/share/syslog-flow/
   sudo useradd --system --no-create-home --shell /usr/sbin/nologin syslog-flow
   sudo chown -R syslog-flow:syslog-flow /var/log/syslog-flow /etc/syslog-flow
   ```

2. Point your host's `rsyslog` at `syslog-flow`'s log layout by copying `rsyslog.conf`'s templates/action into a drop-in file, e.g. `/etc/rsyslog.d/60-syslog-flow.conf`. If you changed the log directory above, update the `dynaFile` template's path (default `/logs/...`) to match. Then restart rsyslog:

   ```bash
   sudo cp rsyslog.conf /etc/rsyslog.d/60-syslog-flow.conf
   sudo sed -i 's#/logs/#/var/log/syslog-flow/#' /etc/rsyslog.d/60-syslog-flow.conf
   sudo systemctl restart rsyslog
   ```

3. Install and enable the `syslog-flow` systemd unit (adjust `TZ`, `SYSLOG_FLOW_LOG_DIR`, and `SYSLOG_FLOW_CONFIG_DIR` as needed):

   ```bash
   sudo cp resources/systemd/syslog-flow.service /etc/systemd/system/syslog-flow.service
   sudo systemctl daemon-reload
   sudo systemctl enable --now syslog-flow.service
   ```

The unit runs as an unprivileged `syslog-flow` user, restarts on failure, and only allows writes to `/logs` and `/config` (matching how `entrypoint.sh` runs the same binary inside the container). Check status/logs with `systemctl status syslog-flow` and `journalctl -u syslog-flow -f`.

## Update

Back up your configuration first in case there is a breaking change.

Then, cd back into the `syslog-flow` folder and run:

```bash
docker compose down
git pull
docker compose up --build -d
```
----

## Notes

- Logs are stored as plain text only. There is no database.
- Completed log days keep a small JSON summary beside their `.log` files, such as `logs/2026/05/05/2026-05-05.json`. Missing or unusable summaries are rebuilt on startup; valid existing summaries are only refreshed from Settings.
- `entrypoint.sh` keeps `rsyslogd` and the web process running together and stops the container if either one exits.
- Basic mobile support is available! To keep it light, I did not implement features like collapsible sidebar, but I did test on iPhones of various sizes and added Jump to Top/Bottom buttons, among other things.
- PRs, issues, and discussions are welcome! However, please keep in mind that this exists to be extremely lightweight. If you need advanced features *(e.g authentication, multi-user support, Grafana)*, feel free to fork the repo and develop a custom version.
- Currently, there is no automatic log pruning. This could change in the future.
- Each log on disk will have an extra timestamp of when the server receives the log. This mitigates issues with devices that report strange dates on boot.
- The Compose file follows the server timezone via `/etc/localtime` (used for day folders and day-based stats)
- syslog-flow is *not* a SIEM. It just accepts, stores, and views logs.
- Why not use a DB? Because there are other solutions for that, and I dislike gray box software which uses a proprietary or hard-to-access DB schema. The logs here are simply text files, and you can move them around freely without breaking anything. Of course, you will want to refresh the JSON caches if you do that :)
- Disclaimer: all Go code was written by GPT 5.6 Terra & 5.4 Codex. However, I did use common sense and I tested everything, as I use this myself.


## Details, Config, and API

Example config for a client rsyslog (`/etc/rsyslog.d/60-syslog-flow.conf`:

```rsyslog
*.* @192.168.x.x:514
```

---

On startup, `syslog-flow` creates missing config files and also fills in missing top-level keys in `app.json` and `status-colors.json`.

Generated files:

- `config/app.json`
- `config/device-colors.json`
- `config/interface-colors.json`
- `config/status-colors.json`

The web UI also includes **Settings**, where these existing JSON files can be edited directly. Its **JSON Caches** section shows cache coverage by month and can refresh a completed month in the background.

### app.json

Controls browser polling intervals and the per-file stats tail cache size:

```json
{
  "live_refresh_seconds": 2,
  "stats_refresh_seconds": 10,
  "overview_refresh_seconds": 10,
  "stats_tail_lines": 1024,
  "stats_tail_max_age_hours": 24
}
```

- `live_refresh_seconds`: how often the live log viewer polls for new lines
- `stats_refresh_seconds`: how often top-bar stats refresh, and how long stats snapshots stay cached
- `overview_refresh_seconds`: how often the `Statistics` page refreshes its totals and device list
- `stats_tail_lines`: how many recent lines per file the stats path may retain in memory
- `stats_tail_max_age_hours`: only files newer than this keep cached tail lines; older files keep cached metadata only

### device-colors.json

Optional per-device heading colors in the UI:

```json
{
  "exact": {
    "OPNsense": "#00B4FF",
    "TrueNAS": "#EB8C00"
  },
  "contains": [
    {
      "match": "ZenWiFi",
      "color": "#FF4D4D"
    }
  ]
}
```

`exact` is checked first. Then `contains` rules are checked top-to-bottom, and the first match wins.

### interface-colors.json

Interface theme colors for light and dark mode:

```json
{
  "light": {
    "accent": "#0078ff",
    "line": "rgba(0, 0, 0, 0.18)"
  },
  "dark": {
    "accent": "#0078ff",
    "line": "#2c3b36"
  }
}
```

This file defines the main interface palette used by the UI. Missing keys fall back to built-in defaults.

### status-colors.json

Optional severity colors for rendered log tags:

```json
{
  "emerg": "#FF4D4D",
  "alert": "#FF4D4D",
  "crit": "#FF4D4D",
  "err": "#FF6B6B",
  "warning": "#FFD166",
  "notice": "#7BDFF2",
  "info": "#9AA89F",
  "debug": "#8E9AAF"
}
```

## API

`GET /api/stats`

Example response:

```json
{
  "critical_5m": 0,
  "today_lines": 48060,
  "all_lines": 48060,
  "lines_per_second": 0,
  "log_bytes": 4823119,
  "log_days": 1,
  "devices": 10
}
```

Home Assistant `configuration.yaml` REST config:

```yaml
rest:
  - resource: http://<YOUR-SERVER-IP>:2200/api/stats
    scan_interval: 30
    sensor:
      - name: "Syslog Lines Per Second"
        unique_id: lines_per_second
        value_template: "{{ value_json.lines_per_second }}"
        unit_of_measurement: "lines/s"
        icon: mdi:speedometer
        state_class: measurement

      - name: "Syslog Lines Today"
        unique_id: today_lines
        value_template: "{{ value_json.today_lines }}"
        unit_of_measurement: "lines"
        icon: mdi:format-list-bulleted
        state_class: total_increasing

      - name: "Syslog Lines All Time"
        unique_id: all_lines
        value_template: "{{ value_json.all_lines }}"
        unit_of_measurement: "lines"
        icon: mdi:format-list-bulleted
        state_class: total_increasing

      - name: "Syslog Critical (5m)"
        unique_id: critical_5m
        value_template: "{{ value_json.critical_5m }}"
        unit_of_measurement: "alerts"
        icon: mdi:alert-plus-outline
        state_class: measurement

      - name: "Syslog Log Days"
        unique_id: log_days
        value_template: "{{ value_json.log_days }}"
        unit_of_measurement: "days"
        icon: mdi:calendar-text-outline
        state_class: measurement

      - name: "Syslog Devices"
        unique_id: devices_count
        value_template: "{{ value_json.devices }}"
        unit_of_measurement: "devices"
        icon: mdi:lan
        state_class: measurement
        
      - name: "Syslog Total Size"
        unique_id: log_bytes
        value_template: "{{ value_json.log_bytes }}"
        unit_of_measurement: "B"
        icon: mdi:folder-text-outline
        state_class: measurement
        device_class: data_size
```
