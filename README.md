# Illuminate

A lightweight browser built for MacOS that uses webkit and includes no arbitrary features or user tracking.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)
![Swift](https://img.shields.io/badge/Swift-5-orange.svg)

## Features

* WebKit-based browsing
* Isolated profiles and Guest mode
* Download manager
* Ad and tracker blocking
* Tab groups, caching, and previews
* Bookmarks and shortcuts
* Cookie management
* History system

## Privacy

Illuminate is designed with privacy in mind:

* No tracking
* No telemetry or user analytics
* No account required
* Tracker blocking
* Cookie management
* Canvas fingerprinting protection

## Screenshots

![Browser Window](screenshots/image1.png)
![Website Example](screenshots/image2.png)

## Requirements

* macOS 26 (Tahoe) or later
* Xcode 26 or later
* Swift 5

## Build

```bash
xcodebuild -project Illuminate.xcodeproj \
  -scheme Illuminate \
  -configuration Debug \
  -destination 'platform=macOS' build
```

## Roadmap

* [ ] Add redirect blocking
* [ ] Increase test coverage beyond 75%
* [ ] Performance optimizations
* [ ] Expand extension support
* [ ] Migrate from Combine → Observation
* [ ] Nuke for image loading
* [ ] KeychainAccess for password management
* [ ] Fix passcode manager password capture
* [ ] Unite all of the app into using UiTheme.swift
* [ ] Write an actual onboarding view instead of AI 

## Known Issues

* [ ] LocalAuthentication for password manager locking
* [ ] Internal links can load the wrong website
* [ ] Default background flashes during fast tab switches
* [ ] New tabs don't focus the URL bar
* [ ] Developer tools don't launch
* [ ] Guest windows can show an infinite spinner
* [ ] Individual history items cannot be deleted
* [ ] Profile window changes sizes (Cause unknown)

## AI Disclosure

AI tools were used during development to assist with implementation and code generation. Generated code was reviewed, tested, and integrated responsibly.

## License

MIT. See [LICENSE](LICENSE).
