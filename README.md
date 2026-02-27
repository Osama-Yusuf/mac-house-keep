# Mac House Keep

Automate macOS disk cleanup tasks. Currently supports Docker pruning with email notifications via [Resend](https://resend.com).

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/osama-yusuf/mac-house-keep.git
cd mac-house-keep

# 2. Make scripts executable
chmod +x scripts/*.sh

# 3. (Optional) Set up email notifications
./scripts/setup-email.sh

# 4. Run Docker cleanup
./scripts/docker-cleanup.sh
```

## What It Cleans

The Docker cleanup script removes **all unused** resources:

- Stopped containers
- Unused images (not just dangling)
- Unused volumes
- Unused networks
- Build cache

## Email Notifications

Email summaries are sent via [Resend](https://resend.com) after each cleanup run. This is optional — the script works fine without it.

### Setup

**Interactive:**

```bash
./scripts/setup-email.sh
```

**Non-interactive:**

```bash
./scripts/setup-email.sh --api-key re_YOUR_KEY --to you@example.com
```

You'll need a free API key from [resend.com/api-keys](https://resend.com/api-keys).

## Scheduling

### Option 1: [launchd](https://medium.com/@chetcorcos/a-simple-launchd-tutorial-9fecfcf2dbb3) (recommended for macOS)

Uses the native macOS scheduler. If your Mac is asleep when a run is due, it catches up when you wake it.

The included plist runs every 3 days (259,200 seconds). To change the interval, edit the `StartInterval` value at [`com.mac-house-keep.docker-cleanup.plist:12`](com.mac-house-keep.docker-cleanup.plist) before installing:

| Interval | Seconds |
|----------|---------|
| Daily | 86400 |
| Every 2 days | 172800 |
| Every 3 days | 259200 |
| Weekly | 604800 |

**Install:**

```bash
cp com.mac-house-keep.docker-cleanup.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.mac-house-keep.docker-cleanup.plist
```

**Unload:**

```bash
launchctl unload ~/Library/LaunchAgents/com.mac-house-keep.docker-cleanup.plist
```

### Option 2: cron (Linux / macOS)

Works on any system. Note: missed runs while the machine is off won't be retried.

```bash
crontab -e
```

Add **one** of these lines (replace the path with your actual install location):

```bash
# Every 3 days at 10:30 AM
30 10 */3 * * /absolute/path/to/mac-house-keep/scripts/docker-cleanup.sh

# Daily at 9:00 AM
0 9 * * * /absolute/path/to/mac-house-keep/scripts/docker-cleanup.sh

# Every Monday at 8:00 AM
0 8 * * 1 /absolute/path/to/mac-house-keep/scripts/docker-cleanup.sh

# Every Sunday and Wednesday at 12:00 PM
0 12 * * 0,3 /absolute/path/to/mac-house-keep/scripts/docker-cleanup.sh
```

## Project Structure

```
mac-house-keep/
├── scripts/
│   ├── common.sh              # Shared: logging, locking, email
│   ├── setup-email.sh         # Configure Resend email notifications
│   └── docker-cleanup.sh      # Docker prune all unused resources
├── config/                    # email.conf created here at runtime (gitignored)
├── logs/                      # Per-script timestamped logs (gitignored)
├── .gitignore
└── README.md
```

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
