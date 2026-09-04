# Releasing Illuminate

This document covers the full release pipeline for distributing Illuminate outside the Mac App Store via GitHub Releases, with Sparkle auto-update support.

## Prerequisites

Install the required tools (one-time setup):

```bash
brew install create-dmg gh
```

Ensure you're authenticated with GitHub:

```bash
gh auth login
```

## One-Time Sparkle Setup (Xcode)

Sparkle handles automatic in-app updates. You must add it to the project once via Xcode:

1. **Open** `Illuminate.xcodeproj` in Xcode
2. **Add package**: File → Add Package Dependencies…
   - URL: `https://github.com/sparkle-project/Sparkle`
   - Version: Up to Next Major (2.x)
3. **Add to target**: Link `Sparkle` to the `Illuminate` target
4. **Generate keys**: In Terminal:
   ```bash
   # Find sign_update after building once
   find ~/Library/Developer/Xcode/DerivedData -name "generate_keys" -type f 2>/dev/null | head -1
   # Run it and save both keys securely
   /path/to/generate_keys
   ```
5. **Add to Info.plist** (via Xcode target → Info tab):
   - `SUFeedURL` → `https://raw.githubusercontent.com/MrBlankCoding/Illuminate/master/appcast.xml`
   - `SUPublicEDKey` → (the public key from step 4)
6. **Build** the project so DerivedData contains `sign_update`

> ⚠️ Keep the **private key** (`sparkle_private_key`) in your macOS Keychain or a secure vault — never commit it. Without it you cannot sign future updates.

## Release Pipeline

```
Bump version → Archive → Notarize → Export → run release CLI
```

### 1. Bump Version in Xcode

In `Illuminate.xcodeproj`:
- `MARKETING_VERSION` — user-facing version (e.g. `1.1`)
- `CURRENT_PROJECT_VERSION` — build number, must increment each release (e.g. `2`)

### 2. Archive

Xcode → **Product → Archive**

### 3. Notarize & Export

In the Archives Organizer:
1. Select archive → **Distribute App**
2. Choose **Developer ID** (direct distribution with notarization)
3. Wait for Apple's notarization servers (~2–5 min)
4. Export to `~/Downloads/Illuminate.app`

### 4. Run the Release CLI

```bash
cd /path/to/Illuminate   # your repo root
go run ./release/cli
```

> **Don't have Go?** Install it: `brew install go`

The CLI will:
1. ✅ Check all required tools
2. ✅ Locate `sign_update` in DerivedData automatically
3. ✅ Read version/build from `~/Downloads/Illuminate.app`
4. ✅ Prompt for release notes (interactive)
5. ✅ Show a summary and ask for confirmation
6. ✅ Create `~/Downloads/Illuminate.dmg` via `create-dmg`
7. ✅ EdDSA-sign the DMG with Sparkle's `sign_update`
8. ✅ Prepend a new `<item>` to `appcast.xml`
9. ✅ `git commit` and `git push` the appcast
10. ✅ Create a GitHub release with the DMG attached

## Manual Steps (if not using the CLI)

<details>
<summary>Expand manual release steps</summary>

### Create DMG

```bash
create-dmg \
  --volname "Illuminate" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 160 \
  --icon "Illuminate.app" 180 170 \
  --app-drop-link 480 170 \
  --hide-extension "Illuminate.app" \
  ~/Downloads/Illuminate.dmg \
  ~/Downloads/Illuminate.app
```

### Sign DMG

```bash
# Find sign_update
SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -type f 2>/dev/null | head -1)
$SIGN_UPDATE ~/Downloads/Illuminate.dmg
# → outputs: sparkle:edSignature="..." length="..."
```

### Update appcast.xml

Add a new `<item>` inside the `<channel>` in `appcast.xml`:

```xml
<item>
  <title>Version 1.1 (Build 2)</title>
  <pubDate>Thu, 04 Sep 2026 00:00:00 +0000</pubDate>
  <sparkle:version>2</sparkle:version>
  <sparkle:shortVersionString>1.1</sparkle:shortVersionString>
  <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
  <description><![CDATA[<ul><li>Your change here</li></ul>]]></description>
  <enclosure url="https://github.com/MrBlankCoding/Illuminate/releases/download/v1.1/Illuminate.dmg"
             type="application/octet-stream"
             sparkle:edSignature="SIGNATURE_FROM_ABOVE"
             length="LENGTH_FROM_ABOVE" />
</item>
```

### Push & Release

```bash
git add appcast.xml
git commit -m "Release v1.1 appcast"
git push origin master

gh release create v1.1 ~/Downloads/Illuminate.dmg \
  --title "v1.1" \
  --notes "- Your change here"
```

</details>

## Appcast URL

The appcast is hosted directly from this repo:

```
https://raw.githubusercontent.com/MrBlankCoding/Illuminate/master/appcast.xml
```

This must match `SUFeedURL` in your app's `Info.plist`.

## Common Issues

| Problem | Fix |
|---------|-----|
| `sign_update` not found | Build the project in Xcode first |
| `gh` auth failure | Run `gh auth login` |
| Duplicate build number warning | Bump `CURRENT_PROJECT_VERSION` before archiving |
| App won't auto-update | Verify `SUFeedURL` points to the **raw** GitHub URL |
| Notarization fails | Check Developer ID certificate and hardened runtime entitlements |
