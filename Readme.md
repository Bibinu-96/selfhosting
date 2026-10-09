# Self-Hosted Home Server: Docker Compose, Cloudflare Tunnel, and Google Drive Backups

A private self-hosted stack that runs on a home PC or a Raspberry Pi. Apps are reached through a Cloudflare Tunnel, so the router needs no open ports. Data is backed up to Google Drive, encrypted with `rclone crypt`, and can be restored on a new machine.

Full write-up: **[add your blog post link]**

## What is in this repo

| File | Purpose |
| --- | --- |
| `docker-compose.yml` | All services and the shared `web` network |
| `.env.example` | Variable names for the secrets `.env` must contain (no real values) |
| `backup.sh` | Stops the containers, archives the data and `.env`, uploads to Google Drive |
| `restore.sh` | Downloads a backup, verifies it, and swaps it in with a rollback copy |
| `.gitignore` | Keeps `.env`, data folders and backup archives out of Git |

## Services

| Service | Purpose |
| --- | --- |
| cloudflared | Cloudflare Tunnel, outbound connection to Cloudflare |
| Ghost | Blog |
| Vaultwarden | Password manager |
| Wiki.js | Personal wiki |
| Vikunja | Task manager |
| n8n | Workflow automation |
| Stirling-PDF | PDF tools |
| IT-Tools | Developer utilities |
| Uptime Kuma | Monitoring, status page and Telegram alerts |
| File Browser | Web file manager |

## Requirements

- A computer that stays on (old PC or Raspberry Pi 4 or 5, 4 GB of RAM or more for n8n and Stirling-PDF)
- Docker with Docker Compose
- A domain you own, with its DNS managed by Cloudflare
- A Cloudflare Tunnel and its token
- A Google account, with `rclone` installed
- A Telegram bot (optional, for alerts)

## Quick start

```bash
git clone <this repo>
cd <this repo>

cp .env.example .env
nano .env                      # fill in the real values

docker network create web      # the compose file expects this network
docker compose up -d
```

Then add one public hostname per app in the Cloudflare dashboard (Zero Trust, Networks, Tunnels). Point each at its container name, for example `http://ghost:2368` or `http://vaultwarden:80`. No `ports:` mappings are needed.

## Backups

1. Set up `rclone` with a Google Drive remote and an encrypted `crypt` remote on top of it:

   ```bash
   rclone config            # create "gdrive", then a crypt remote named "gdrive-crypt"
   ```

2. Check the settings at the top of `backup.sh`: `PROJECT_PATH`, `BACKUP_DIR` and `GDRIVE_REMOTE`.
3. Run it once by hand, then check the archive appears in Google Drive.
4. Schedule it:

   ```bash
   crontab -e
   0 3 * * * /root/project/backup.sh >> /var/log/vps-backup.log 2>&1
   ```

Each archive contains the data folders plus `.env` and `docker-compose.yml`. Without those two files, a restore has no secrets and no list of services.

## Restore

On a new machine:

1. Install Docker and `rclone`, and reconnect the same `rclone` remotes.
2. Run `./restore.sh` and choose a backup.
3. Run `docker network create web` and `docker compose up -d`.

The restore script verifies the archive, extracts it to a staging folder, moves the current data to a `pre-restore_<timestamp>` folder, and then swaps the restored data in. **Test a restore at least once.** A backup you have never restored may not work.

## Security notes

- Never commit `.env`, the data folders or backup archives.
- Publish no `ports:`. The tunnel reaches containers by name over the `web` network.
- Enable two-factor login in every app that supports it.
- Set `SIGNUPS_ALLOWED=false` in Vaultwarden once your account exists, and store `ADMIN_TOKEN` as an Argon2 hash.
- Some apps, such as Stirling-PDF, have no login unless you turn it on. Check each app before exposing it.
- Mount only the folders each container needs. Never mount `/`.
- Pin image versions for apps that hold real data, and upgrade on purpose.

## Known limits

- A home power or internet outage takes everything offline. Uptime Kuma runs on the same machine, so add one external check.
- Cloudflare is a dependency. If the tunnel is down, the public hostnames stop working.
- Ghost on SQLite works for a small blog, but MySQL 8 is the officially supported production database.
- Wiki.js needs `DB_FILEPATH` (not `DB_FILE`) so its SQLite database lands in the backed-up folder.
