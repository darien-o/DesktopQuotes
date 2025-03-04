# Contributing to DesktopQuotes

Thank you for your interest in contributing to DesktopQuotes! This document provides guidelines and instructions for contributing.

## Code of Conduct

Be respectful, inclusive, and constructive in all interactions. We're here to build something great together.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/yourusername/DesktopQuotes/issues)
2. If not, create a new issue with:
   - Clear, descriptive title
   - macOS version and app version
   - Steps to reproduce the bug
   - Expected vs actual behavior
   - Screenshots or logs if applicable
   - Relevant logs from Console.app or `./run_with_logs.sh`

### Suggesting Features

1. Check if the feature has already been suggested
2. Create a new issue with the "enhancement" label
3. Describe:
   - The problem you're trying to solve
   - Your proposed solution
   - Alternative solutions you've considered
   - Any implementation details

### Contributing Code

#### Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/yourusername/DesktopQuotes.git
   cd DesktopQuotes
   ```

3. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

4. Make your changes

5. Test your changes:
   ```bash
   # Run tests
   xcodebuild test -project DesktopQuotes.xcodeproj -scheme DesktopQuotes
   
   # Test manually
   ./run_with_logs.sh
   ```

6. Commit your changes:
   ```bash
   git add .
   git commit -m "Add feature: your feature description"
   ```

7. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

8. Open a Pull Request

#### Code Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused (< 50 lines ideally)
- Use emoji prefixes in log messages:
  - 🔍 = Starting operation
  - 📡 = Network request
  - ✅ = Success
  - ❌ = Error
  - 🔄 = Retry/sync operation
  - 🪟 = Window operation
  - 🖥️ = Screen detection

#### Testing

- Write unit tests for new features
- Ensure all existing tests pass
- Test on multiple screens if possible
- Test with and without internet connection
- Test on different macOS versions if possible

#### Documentation

- Update README.md if you add features
- Add inline comments for complex code
- Update CLI_DEBUG.md if you add debugging features
- Document any new configuration options

### Specific Contribution Areas

#### Adding Quote Sources

1. Edit `DesktopQuotes/RemoteQuoteSync.swift`
2. Add your source to `fetchAllSources()`:
   ```swift
   let mySource = QuoteSource(
       id: "my-source",
       url: "https://api.example.com/quotes",
       name: "My Quote Source",
       enabled: true
   )
   ```

3. Add parsing logic if the API format is different
4. Update README.md with the new source
5. Test thoroughly with the new source

#### Adding Languages

1. Edit `DesktopQuotes/LanguageManager.swift`
2. Add your language to `supportedLanguages`:
   ```swift
   Language(code: "es", name: "Español", nativeName: "Español")
   ```

3. Add translations for UI elements
4. Test with quotes in that language
5. Update README.md

#### Improving Multi-Screen Support

1. Test on systems with 1, 2, 3+ monitors
2. Check `DesktopQuotes/MultiWindowManager.swift`
3. Add logging to help debug issues
4. Test screen connect/disconnect scenarios
5. Test with different screen arrangements

#### Improving Performance

1. Profile the app with Instruments
2. Identify bottlenecks
3. Optimize without sacrificing readability
4. Add performance tests if applicable
5. Document performance improvements

## Pull Request Guidelines

### Before Submitting

- [ ] Code follows the style guidelines
- [ ] All tests pass
- [ ] New tests added for new features
- [ ] Documentation updated
- [ ] Commit messages are clear and descriptive
- [ ] No merge conflicts with main branch

### PR Description

Include:
- What changes you made
- Why you made them
- How to test the changes
- Screenshots/videos if UI changes
- Related issue numbers (e.g., "Fixes #123")

### Review Process

1. Maintainers will review your PR
2. Address any feedback or requested changes
3. Once approved, your PR will be merged
4. Your contribution will be credited in the release notes

## Development Environment

### Requirements

- macOS 15.2 or later
- Xcode 15.0 or later
- Swift 5.0 or later

### Building

```bash
# Clean build
xcodebuild -project DesktopQuotes.xcodeproj -scheme DesktopQuotes -configuration Debug clean build

# Run with logs
./run_with_logs.sh

# Run tests
xcodebuild test -project DesktopQuotes.xcodeproj -scheme DesktopQuotes
```

### Debugging

```bash
# Test network connectivity
./test_network.sh

# Manual quote download (for corporate networks)
./download_quotes.sh

# View detailed logs
./run_with_logs.sh

# Test network fix
./test_network_fix.sh
```

See [CLI_DEBUG.md](CLI_DEBUG.md) for comprehensive debugging guide.

## Project Structure

```
DesktopQuotes/
├── Models/
│   ├── Quote.swift              # Quote data model
│   └── QuoteSource.swift        # Quote source configuration
├── Data Layer/
│   ├── LocalQuoteStore.swift    # Local JSON storage
│   ├── QuoteRepository.swift    # Data access layer
│   └── RemoteQuoteSync.swift    # API synchronization
├── Business Logic/
│   ├── QuoteManager.swift       # Quote management & caching
│   ├── LanguageManager.swift    # Multi-language support
│   └── BackgroundUpdateScheduler.swift  # Background sync
├── UI/
│   ├── DesktopQuotesApp.swift   # App entry point
│   ├── MultiWindowManager.swift # Multi-screen management
│   └── ContentView.swift        # Main UI
└── Tests/
    ├── DesktopQuotesTests/      # Unit tests
    └── Property-based tests     # Correctness tests
```

## Architecture Principles

- **Clean Architecture**: Clear separation of concerns
- **Testability**: All components are testable
- **SOLID Principles**: Single responsibility, dependency injection
- **Protocol-Oriented**: Use protocols for abstraction
- **SwiftUI**: Modern declarative UI
- **Async/Await**: Modern concurrency

## Questions?

- Open a [Discussion](https://github.com/yourusername/DesktopQuotes/discussions)
- Ask in your Pull Request
- Check existing issues and PRs

## Recognition

Contributors will be:
- Listed in release notes
- Credited in the README
- Thanked in commit messages

Thank you for contributing to DesktopQuotes! 🎉
