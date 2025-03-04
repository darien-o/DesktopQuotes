# DesktopQuotes

A minimalist macOS app that displays inspirational quotes on your desktop background, behind all windows and applications.

## Features

- **Multi-Screen Support**: Shows different quotes on each connected display
- **Multi-Desktop Support**: Different quotes appear on each macOS desktop/space
- **Background Display**: Quotes appear behind all apps, even desktop folders
- **Automatic Updates**: Fetches fresh quotes from ZenQuotes API
- **Smart Caching**: Stores quotes locally with duplicate detection
- **Offline Mode**: Works without internet using cached quotes
- **Multi-Language Support**: 25 languages supported with user preferences
- **Adaptive Colors**: Text colors adjust based on desktop background (requires screen recording permission)
- **Battery Friendly**: Defers updates when battery < 20% or CPU > 80%

## Installation

1. Clone the repository
2. Open `DesktopQuotes.xcodeproj` in Xcode
3. Build and run (Cmd + R)

```bash
# Or build from command line
xcodebuild -project DesktopQuotes.xcodeproj -scheme DesktopQuotes -configuration Debug build
```

## Usage

The app runs automatically on launch and displays quotes on all screens and desktops. Quotes change when you switch between desktops/spaces.

### Permissions

- **Screen Recording** (optional): Enables adaptive text colors based on your wallpaper
- **Network Access**: Required to fetch new quotes from ZenQuotes API

## Quote Source

Quotes are fetched from [ZenQuotes.io](https://zenquotes.io/), a free quote API that doesn't require authentication.

API endpoint: `https://zenquotes.io/api/quotes`

Response format:
```json
[
  {
    "q": "The decisions of our past are the architects of our present.",
    "a": "Dan Brown",
    "h": "<blockquote>...</blockquote>"
  }
]
```

## Technical Details

- **Storage**: Quotes are stored locally in JSON format in Application Support directory
- **Sync**: Background updates run daily (configurable)
- **Duplicate Prevention**: Quotes are deduplicated by text content
- **Window Level**: Uses desktop window level to stay behind all apps
- **Architecture**: MVVM with SwiftUI
- **Persistence**: LocalQuoteStore with atomic writes and file permissions

## Project Structure

```
DesktopQuotes/
├── DesktopQuotesApp.swift           # App entry point with multi-window manager
├── ContentView.swift                 # Quote display views
├── MultiWindowManager.swift          # Manages windows for each screen/desktop
├── Quote.swift                       # Quote data model
├── QuoteManager.swift                # Quote management with sync logic
├── QuoteRepository.swift             # Data persistence and sync
├── LocalQuoteStore.swift             # JSON file storage
├── RemoteQuoteSync.swift             # Network sync with ZenQuotes API
├── BackgroundUpdateScheduler.swift   # Battery-friendly background updates
├── LanguageManager.swift             # Multi-language support
├── TransparentWindow.swift           # Window transparency configuration
└── Assets.xcassets/                  # App assets and icons
```

## Requirements

- macOS 12.0 or later
- Xcode 14.0 or later (for development)
- Internet connection for initial quote fetch

## Customization

### Change Update Frequency

Edit `QuoteManager.swift` and modify the scheduler interval:

```swift
scheduler.scheduleUpdates(interval: .hourly)  // or .daily, .weekly
```

### Add Custom Quote Sources

Edit `RemoteQuoteSync.swift` and add your API endpoint to `fetchAllSources()`.

### Adjust Quote Position

Edit `SingleQuoteView` in `MultiWindowManager.swift` to change positioning and styling.

## Known Limitations

- Requires screen recording permission for adaptive colors (optional)
- Background updates respect battery and CPU constraints
- Maximum 100 quotes per sync to prevent excessive storage

## Troubleshooting

### Quotes not appearing
- Check that the app has launched (look for icon in menu bar or Activity Monitor)
- Try switching desktops/spaces to trigger a refresh

### No new quotes fetched
- Check internet connection
- Verify network permissions in System Preferences > Security & Privacy
- Check Console.app for error logs

### Quotes appear on top of windows
- Restart the app - window level should be set to desktop level on launch

## License

MIT License - feel free to use and modify as needed.

## Author

Created by Darien Stiven Osorno Ramirez

## Contributing

Contributions are welcome! Here's how you can help:

### Ways to Contribute

1. **Add Quote Sources**
   - Fork the repository
   - Add your quote source to `RemoteQuoteSync.swift`
   - Update this README with the new source
   - Submit a pull request

2. **Add Language Support**
   - Add language code to `LanguageManager.swift`
   - Add translations for UI elements
   - Test with quotes in that language
   - Submit a pull request

3. **Report Bugs**
   - Use GitHub Issues
   - Include macOS version, app version, and steps to reproduce
   - Attach relevant logs from Console.app or `./run_with_logs.sh`

4. **Suggest Features**
   - Open a GitHub Issue with the "enhancement" label
   - Describe the feature and its use case
   - Discuss implementation approach

### Development Setup

```bash
# Clone the repo
git clone https://github.com/yourusername/DesktopQuotes.git
cd DesktopQuotes

# Open in Xcode
open DesktopQuotes.xcodeproj

# Or build from command line
xcodebuild -project DesktopQuotes.xcodeproj -scheme DesktopQuotes -configuration Debug build

# Run with enhanced logging
./run_with_logs.sh

# Run tests
xcodebuild test -project DesktopQuotes.xcodeproj -scheme DesktopQuotes
```

### Code Style Guidelines

- Follow Swift API Design Guidelines
- Use meaningful variable names
- Add comments for complex logic
- Write tests for new features
- Keep functions small and focused
- Use emoji prefixes in log messages (🔍 📡 ✅ ❌ 🔄)

### Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests if applicable
5. Ensure all tests pass
6. Update documentation
7. Commit your changes (`git commit -m 'Add amazing feature'`)
8. Push to your fork (`git push origin feature/amazing-feature`)
9. Open a Pull Request

### Testing

The project includes comprehensive tests:

- Unit tests for data layer
- Property-based tests for correctness
- Integration tests for sync operations

Run tests with:
```bash
xcodebuild test -project DesktopQuotes.xcodeproj -scheme DesktopQuotes
```

### Debugging Tools

```bash
# Test network connectivity
./test_network.sh

# Manual quote download (for corporate networks)
./download_quotes.sh

# View detailed logs with emoji prefixes
./run_with_logs.sh

# Test network fix
./test_network_fix.sh
```

See [CLI_DEBUG.md](CLI_DEBUG.md) for comprehensive debugging guide.

## Acknowledgments

- Quotes provided by [ZenQuotes.io](https://zenquotes.io/)
- Built with SwiftUI and modern macOS APIs
