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

## Features to implement

* [ ] Add redirect blocking
* [ ] Increase test coverage beyond 75%
* [ ] Performance optimizations
* [ ] Expand extension support
* [ ] Nuke for image loading
* [ ] KeychainAccess for password management
* [ ] Write an actual onboarding view instead of AI 
* [ ] Haptic feedback for actions like reordering tabs
* [ ] Build in whiteboard
* [ ] Build theme picker similar to act (1/3 done)

## Known Issues

* [ ] Internal links can cause the website to load wrong and URL bar doesnt update -> preconnecting error?
* [ ] Guest windows can show an infinite spinner
* [ ] When saving PDF's the whole page is not captured

## Contributing
If you'd like to report a bug, please do under issues

Illuminate is open-source for a reason, and any contributions from anyone is welcome! 

## AI Disclosure

AI tools were used during development to assist with implementation and code generation. Generated code was reviewed, tested, and integrated responsibly.

## License

MIT. See [LICENSE](LICENSE).
