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

