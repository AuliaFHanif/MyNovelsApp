# PocketBase Feed Monitor Setup Guide

This guide will help you set up automatic feed monitoring for your Novel Reader app using PocketBase JavaScript hooks.

## 📋 What This Does

The feed monitor will:

- ✅ Automatically check DeviantArt RSS feeds every 6 hours
- ✅ Create notifications when artists post new chapters
- ✅ Track which posts you've already seen
- ✅ Clean up old notifications after 7 days
- ✅ Work completely in the background (no manual checks needed)

## 🚀 Quick Setup (5 minutes)

### Step 1: Locate Your PocketBase Installation

You need to find where PocketBase is installed on your computer. Common locations:

- `C:\pocketbase\`
- `C:\Users\[YourUsername]\pocketbase\`
- Or wherever you extracted the PocketBase executable

The directory should contain:

- `pocketbase.exe` (Windows) or `pocketbase` (Linux/Mac)
- `pb_data\` folder

### Step 2: Copy the Hook File

1. **Stop PocketBase** if it's currently running (press Ctrl+C in the terminal)

2. **Navigate to your PocketBase folder:**

   ```powershell
   cd C:\path\to\your\pocketbase
   ```

3. **Create the `pb_hooks` directory** if it doesn't exist:

   ```powershell
   mkdir pb_hooks
   ```

4. **Copy the hook file:**
   - Source: `C:\Users\fhani\Documents\Code\MyNovelsApp\pb_hooks\main.pb.js`
   - Destination: `[Your PocketBase Directory]\pb_hooks\main.pb.js`

   ```powershell
   # Example command:
   copy C:\Users\fhani\Documents\Code\MyNovelsApp\pb_hooks\main.pb.js .\pb_hooks\main.pb.js
   ```

### Step 3: Restart PocketBase

```powershell
# Make sure you're in your PocketBase directory
cd C:\path\to\your\pocketbase

# Start PocketBase
.\pocketbase.exe serve
```

**Look for these messages in the console:**

```
[Feed Monitor] Loading feed monitoring hook...
[Feed Monitor] Hook loaded successfully
[Feed Monitor] Cron job registered: check_feeds (every 6 hours)
```

If you see these → **Success!** 🎉

### Step 4: Test the Feed Monitor

Open a new terminal and test the endpoint:

```powershell
Invoke-WebRequest -Uri 'http://127.0.0.1:8090/api/custom/check-feeds' -Method POST
```

You should get a JSON response like:

```json
{
  "success": true,
  "timestamp": "2026-02-19T10:30:00Z",
  "sourcesChecked": 0,
  "totalNewNotifications": 0,
  "results": []
}
```

## 📁 Final Directory Structure

Your PocketBase folder should look like this:

```
C:\pocketbase\                    (or wherever yours is)
├── pocketbase.exe
├── pb_data\
│   ├── logs\
│   │   └── pocketbase.log       (check here for errors)
│   └── data.db
└── pb_hooks\                     ← YOU CREATED THIS
    └── main.pb.js                ← YOU COPIED THIS
```

## 🔧 How It Works

### Automatic Checks

The cron job runs **every 6 hours** at:

- 00:00 (midnight)
- 06:00 (6 AM)
- 12:00 (noon)
- 18:00 (6 PM)

### Manual Check

You can also trigger a check manually anytime:

```powershell
Invoke-WebRequest -Uri 'http://127.0.0.1:8090/api/custom/check-feeds' -Method POST
```

### What Gets Monitored

The hook will:

1. Find all active sources in `monitored_sources` collection
2. For each source with `is_active = true`:
   - Derive the RSS URL (e.g., `https://www.deviantart.com/artist/rss`)
   - Fetch the RSS feed
   - Parse all items
   - Check if notifications already exist (avoids duplicates)
   - Create new notifications for new posts
3. Clean up notifications older than 7 days

## 📊 Using the Feed Monitor in Your App

### Subscribe to an Artist

In your Flutter app, go to the Feed Panel and:

1. Click "Subscribe to Artist"
2. Select a series
3. Enter the DeviantArt artist URL: `https://www.deviantart.com/[username]`
4. Click Subscribe

The app will create a record in `monitored_sources` collection.

### View Notifications

1. Open the Feed Panel
2. Go to the "Notifications" tab
3. You'll see all new chapters posted by artists you follow
4. Click a notification to:
   - Mark it as read
   - Open the DeviantArt post in your browser

## 🎨 Customizing the Schedule

To change how often feeds are checked, edit `pb_hooks\main.pb.js`:

Find this line (~line 286):

```javascript
$app.Cron().MustAdd("check_feeds", "0 */6 * * *", () => {
```

Change the schedule:

- **Every hour**: `"0 * * * *"`
- **Every 3 hours**: `"0 */3 * * *"`
- **Every 12 hours**: `"0 */12 * * *"`
- **Every day at 2 AM**: `"0 2 * * *"`
- **Every 30 minutes**: `"*/30 * * * *"`

Then restart PocketBase.

## 🐛 Troubleshooting

### Hook not loading

**Symptoms:** No `[Feed Monitor]` messages in console

**Solutions:**

1. Verify file is named exactly: `main.pb.js`
2. Verify file is in `pb_hooks\` directory (not `pb_hook\` or elsewhere)
3. Check for syntax errors in the file
4. Restart PocketBase
5. Check `pb_data\logs\pocketbase.log` for errors

### No notifications being created

**Symptoms:** Endpoint returns `sourcesChecked: 0`

**Solutions:**

1. Check you have records in `monitored_sources` collection
2. Make sure `is_active = true` on the source
3. Verify the series exists (check `series_id` is valid)
4. Test the RSS URL manually in browser:
   ```
   https://www.deviantart.com/[artist]/rss
   ```
5. Check logs: `pb_data\logs\pocketbase.log`

### Cron not running automatically

**Symptoms:** Hook loads but automatic checks don't happen

**Solutions:**

1. Test manually with the HTTP endpoint (see Step 4)
2. PocketBase must stay running for cron to work
3. Check PocketBase version (JS cron requires v0.17+)
4. Watch the logs to see when checks run

### "Collection not found" error

**Symptoms:** Error about `monitored_sources` or `feed_notifications` not found

**Solution:** Create the collections in PocketBase Admin UI:

#### Create `monitored_sources` collection:

Fields:

- `series_id` (Relation → series) _required_
- `artist_name` (Text) _required_
- `source_url` (Text) _required_
- `source_type` (Text, default: "deviantart")
- `rss_url` (Text, optional)
- `is_active` (Bool, default: true)
- `last_checked` (DateTime, optional)
- `last_found_url` (Text, optional)

#### Create `feed_notifications` collection:

Fields:

- `monitored_source_id` (Relation → monitored_sources) _required_
- `series_id` (Relation → series) _required_
- `artist_name` (Text) _required_
- `series_title` (Text) _required_
- `chapter_title` (Text, optional)
- `post_url` (Text) _required_
- `thumbnail_url` (Text, optional)
- `is_read` (Bool, default: false)

## 📝 Viewing Logs

To see what the feed monitor is doing:

**Windows PowerShell:**

```powershell
Get-Content pb_data\logs\pocketbase.log -Wait -Tail 50
```

**Linux/Mac/Git Bash:**

```bash
tail -f pb_data/logs/pocketbase.log
```

Look for lines starting with `[Feed Monitor]`

## 🔄 Keep PocketBase Running

For automatic feed checks to work, **PocketBase must be running 24/7**.

### Option 1: Run in Background (Simple)

```powershell
# Windows - Run in background
Start-Process -FilePath ".\pocketbase.exe" -ArgumentList "serve" -WindowStyle Hidden
```

### Option 2: Windows Task Scheduler (Recommended)

1. Open Task Scheduler
2. Create Basic Task
3. Trigger: "At startup"
4. Action: "Start a program"
5. Program: `C:\path\to\pocketbase.exe`
6. Arguments: `serve`
7. Start in: `C:\path\to\pocketbase\`

### Option 3: Windows Service (Advanced)

Use a tool like NSSM (Non-Sucking Service Manager) to run PocketBase as a Windows service.

## ✅ Testing Checklist

After setup, verify everything works:

- [ ] Hook file copied to `pb_hooks\main.pb.js`
- [ ] PocketBase restarted
- [ ] Console shows `[Feed Monitor] Hook loaded successfully`
- [ ] Manual test endpoint works (returns JSON)
- [ ] `monitored_sources` collection exists
- [ ] `feed_notifications` collection exists
- [ ] Test artist subscription works in app
- [ ] Can see notifications in Feed Panel

## 🆘 Getting Help

If you're stuck:

1. Check `pb_data\logs\pocketbase.log` for errors
2. Test the endpoint manually (see Step 4)
3. Verify collections exist in PocketBase Admin
4. Make sure PocketBase version is 0.17 or newer

## 🎯 Next Steps

1. ✅ Follow this setup guide
2. ✅ Test with one artist subscription
3. ✅ Wait for automatic check (or trigger manually)
4. ✅ Verify notifications appear in your app
5. ✅ Set up PocketBase to run at startup

---

**That's it!** Your feed monitor is now set up and will automatically check for new chapters every 6 hours. 🚀
