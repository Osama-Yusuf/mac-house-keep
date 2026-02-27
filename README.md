# Mac House Keep

Automate macOS disk cleanup tasks with email notifications via [Resend](https://resend.com).

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/osama-yusuf/mac-house-keep.git
cd mac-house-keep

# 2. Make scripts executable
chmod +x scripts/*.sh

# 3. (Optional) Set up email notifications
./scripts/setup-email.sh

# 4. Run any cleanup script
./scripts/docker-cleanup.sh
./scripts/homebrew-cleanup.sh
./scripts/xcode-cleanup.sh
./scripts/dev-caches-cleanup.sh
./scripts/system-cleanup.sh
./scripts/old-downloads-cleanup.sh
```

## What It Cleans

| Script | What it removes | Typical savings |
|--------|----------------|-----------------|
| `docker-cleanup.sh` | Stopped containers, unused images, volumes, networks, build cache | 5-50 GB |
| `homebrew-cleanup.sh` | Cached downloads, old formula versions, orphaned deps | 2-15 GB |
| `xcode-cleanup.sh` | DerivedData, archives, old simulators, device support, previews, caches | 20-100+ GB |
| `dev-caches-cleanup.sh` | npm, yarn, pnpm, bun, pip, CocoaPods, Go, Cargo, Gradle, Maven, Composer, gem, Conda | 5-30 GB |
| `system-cleanup.sh` | User caches, logs, crash reports, Trash | 2-15 GB |
| `old-downloads-cleanup.sh` | `.dmg` and `.pkg` files older than 10 days in ~/Downloads | 2-30 GB |

Everything cleaned is either a cache (auto-regenerates) or disposable junk. No personal data is touched.

## Email Notifications

Email summaries are sent via [Resend](https://resend.com) after each cleanup run. This is optional — scripts work fine without it.

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

The included plist runs `scripts/run-all.sh` (all cleanup scripts) every 3 days (259,200 seconds). To change the interval, edit the `StartInterval` value at [`com.mac-house-keep.plist:12`](com.mac-house-keep.plist):

| Interval | Seconds |
|----------|---------|
| Daily | 86400 |
| Every 2 days | 172800 |
| Every 3 days | 259200 |
| Weekly | 604800 |

**Before installing, update the 3 paths in the plist** (lines [9](com.mac-house-keep.plist), [14](com.mac-house-keep.plist), and [16](com.mac-house-keep.plist)) to match where you cloned the repo. Replace `/CHANGE/THIS/PATH/TO/mac-house-keep` with your actual path:

```xml
<!-- Line 9: script path -->
<string>/Users/YOUR_USERNAME/path/to/mac-house-keep/scripts/run-all.sh</string>

<!-- Lines 14 & 16: log path -->
<string>/Users/YOUR_USERNAME/path/to/mac-house-keep/logs/launchd.log</string>
```

**Install:**

```bash
cp com.mac-house-keep.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.mac-house-keep.plist
```

**Verify it's loaded:**

```bash
launchctl list | grep mac-house-keep
```

**Unload:**

```bash
launchctl unload ~/Library/LaunchAgents/com.mac-house-keep.plist
```

### Option 2: cron (Linux / macOS)

Works on any system. Note: missed runs while the machine is off won't be retried.

```bash
crontab -e
```

Add **one** of these lines (replace the path with your actual install location):

**Run all scripts together:**

```bash
# Every 3 days at 10:30 AM
30 10 */3 * * /absolute/path/to/mac-house-keep/scripts/run-all.sh

# Daily at 9:00 AM
0 9 * * * /absolute/path/to/mac-house-keep/scripts/run-all.sh

# Every Monday at 8:00 AM
0 8 * * 1 /absolute/path/to/mac-house-keep/scripts/run-all.sh
```

**Or schedule scripts individually on different intervals:**

```bash
# Docker cleanup every 3 days at 10:30 AM
30 10 */3 * * /absolute/path/to/mac-house-keep/scripts/docker-cleanup.sh

# System cleanup weekly on Monday at 9:00 AM
0 9 * * 1 /absolute/path/to/mac-house-keep/scripts/system-cleanup.sh

# Dev caches cleanup every 2 weeks on the 1st and 15th at 10:00 AM
0 10 1,15 * * /absolute/path/to/mac-house-keep/scripts/dev-caches-cleanup.sh
```

## Project Structure

```
mac-house-keep/
├── scripts/
│   ├── common.sh                # Shared: logging, locking, email
│   ├── setup-email.sh           # Configure Resend email notifications
│   ├── run-all.sh               # Run all cleanup scripts sequentially
│   ├── docker-cleanup.sh        # Docker prune all unused resources
│   ├── homebrew-cleanup.sh      # Homebrew cache, old versions, orphaned deps
│   ├── xcode-cleanup.sh         # Xcode DerivedData, simulators, device support
│   ├── dev-caches-cleanup.sh    # Package manager caches (npm, pip, Go, etc.)
│   ├── system-cleanup.sh        # User caches, logs, crash reports, Trash
│   └── old-downloads-cleanup.sh # Old .dmg/.pkg installers in ~/Downloads
├── config/                      # email.conf created here at runtime (gitignored)
├── logs/                        # Per-script timestamped logs (gitignored)
├── com.mac-house-keep.plist     # launchd template (edit paths before installing)
├── .gitignore
├── LICENSE
└── README.md
```

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
