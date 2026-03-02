# Installing DesktopQuotes

## Quick Install

1. Download `DesktopQuotes.zip`
2. Unzip the file (double-click)
3. Drag `DesktopQuotes.app` to your Applications folder
4. Double-click to open

## First Launch

When you first open the app, macOS may show a security warning because the app is not signed with an Apple Developer certificate.

### If you see "DesktopQuotes can't be opened"

1. **Right-click** (or Control-click) on `DesktopQuotes.app`
2. Select **"Open"** from the menu
3. Click **"Open"** in the security dialog

You only need to do this once. After that, you can open the app normally.

### Alternative Method

1. Open **System Settings** → **Privacy & Security**
2. Scroll down to the Security section
3. Click **"Open Anyway"** next to the DesktopQuotes message
4. Click **"Open"** in the confirmation dialog

## What to Expect

After opening the app:

1. **Menu Bar Icon**: A quote bubble icon appears in your menu bar
2. **Quotes Download**: The app downloads quotes from the internet (requires network access)
3. **Desktop Quotes**: Inspirational quotes appear on all your screens
4. **Behind Windows**: Quotes stay behind all your apps and windows

## Features

- **Multi-Monitor Support**: Different quotes on each screen
- **Desktop Spaces**: Quotes change when you switch desktops (Ctrl+Left/Right)
- **Random Positioning**: Quotes appear in different positions
- **Auto-Update**: New quotes download daily
- **Offline Mode**: Works without internet using cached quotes

## Menu Bar Controls

Click the quote bubble icon in the menu bar:

- **Refresh Quotes** (⌘R) - Show new random quotes
- **Sync from API** (⌘S) - Download new quotes
- **Show Quotes Folder** - Open quotes storage
- **Quit** (⌘Q) - Exit the app

## Requirements

- macOS 15.2 or later
- Internet connection (for downloading quotes)
- Multiple monitors (optional, but recommended)

## Troubleshooting

### App won't open

**Problem**: "DesktopQuotes is damaged and can't be opened"

**Solution**: Open Terminal and run:
```bash
xattr -cr /Applications/DesktopQuotes.app
```

Then try opening the app again.

### No quotes appearing

**Problem**: Quotes don't show up on screen

**Solutions**:
1. Check if the app is running (look for menu bar icon)
2. Try "Refresh Quotes" from the menu bar
3. Check your internet connection
4. Look for quotes in Console.app (filter by "DesktopQuotes")

### Quotes only on one screen

**Problem**: Quotes only appear on laptop screen, not external monitors

**Solutions**:
1. Quit and restart the app after connecting monitors
2. Use "Refresh Quotes" from the menu bar
3. Disconnect and reconnect monitors

### Network errors

**Problem**: "Cannot download quotes" or DNS errors

**Solutions**:
1. Check your internet connection
2. If on corporate network/VPN, the firewall may block zenquotes.io
3. Try disabling VPN temporarily
4. The app will use cached quotes if network is unavailable

## Uninstalling

To remove DesktopQuotes:

1. Quit the app (⌘Q from menu bar)
2. Delete `DesktopQuotes.app` from Applications folder
3. (Optional) Delete cached quotes:
   ```bash
   rm -rf ~/Library/Application\ Support/DesktopQuotes
   ```

## Privacy

DesktopQuotes:
- ✅ Does NOT collect your data
- ✅ Does NOT track your usage
- ✅ Only connects to zenquotes.io for quotes
- ✅ Stores quotes locally on your Mac
- ✅ No analytics or telemetry

## Support

- **Bug Reports**: [GitHub Issues](https://github.com/yourusername/DesktopQuotes/issues)
- **Questions**: [GitHub Discussions](https://github.com/yourusername/DesktopQuotes/discussions)
- **Documentation**: [README.md](README.md)

## Updates

To update to a new version:

1. Download the latest `DesktopQuotes.zip`
2. Quit the current version
3. Replace the old app with the new one
4. Open the new version

Your quotes and settings are preserved.

## Getting Started

After installation:

1. **First Launch**: Wait a few seconds for quotes to download
2. **Check All Screens**: Look at each monitor for quotes
3. **Try Desktop Switching**: Press Ctrl+Left or Ctrl+Right to switch desktops
4. **Explore Menu Bar**: Click the quote bubble icon to see options
5. **Enjoy**: Daily inspiration on your desktop!

---

**Need Help?** Open an issue on GitHub or check the [troubleshooting guide](CLI_DEBUG.md).
