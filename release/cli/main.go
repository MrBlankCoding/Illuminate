// release - interactive release CLI for Illuminate
// Automates: DMG creation → Sparkle signing → appcast update → git push → GitHub release
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// ─── Config ──────────────────────────────────────────────────────────────────

type Config struct {
	AppName              string   `json:"app_name"`
	GithubRepo           string   `json:"github_repo"`
	BundleName           string   `json:"bundle_name"`
	DMGName              string   `json:"dmg_name"`
	GitBranch            string   `json:"git_branch"`
	MinSystemVersion     string   `json:"min_system_version"`
	AppcastFile          string   `json:"appcast_file"`
	DerivedDataPrefixes  []string `json:"derived_data_prefixes"`
}

func loadConfig() (*Config, string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return nil, "", err
	}
	for {
		path := filepath.Join(dir, "release.json")
		if data, err := os.ReadFile(path); err == nil {
			var cfg Config
			if err := json.Unmarshal(data, &cfg); err != nil {
				return nil, "", fmt.Errorf("invalid release.json: %w", err)
			}
			// Apply defaults
			if cfg.BundleName == "" {
				cfg.BundleName = cfg.AppName + ".app"
			}
			if cfg.DMGName == "" {
				cfg.DMGName = cfg.AppName + ".dmg"
			}
			if cfg.GitBranch == "" {
				cfg.GitBranch = "main"
			}
			if cfg.MinSystemVersion == "" {
				cfg.MinSystemVersion = "14.0"
			}
			if cfg.AppcastFile == "" {
				cfg.AppcastFile = "appcast.xml"
			}
			if len(cfg.DerivedDataPrefixes) == 0 {
				cfg.DerivedDataPrefixes = []string{cfg.AppName + "-"}
			}
			return &cfg, dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return nil, "", fmt.Errorf("release.json not found (walked up from %s)", dir)
}

// ─── Tool checks ─────────────────────────────────────────────────────────────

func requireTool(name string) error {
	if _, err := exec.LookPath(name); err != nil {
		return fmt.Errorf("required tool %q not found in PATH (install with: brew install %s)", name, name)
	}
	return nil
}

func findSignUpdate(prefixes []string) (string, error) {
	ddBase := filepath.Join(os.Getenv("HOME"), "Library", "Developer", "Xcode", "DerivedData")
	entries, err := os.ReadDir(ddBase)
	if err != nil {
		return "", fmt.Errorf("cannot read DerivedData: %w", err)
	}
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		matched := false
		for _, prefix := range prefixes {
			if strings.HasPrefix(e.Name(), prefix) {
				matched = true
				break
			}
		}
		if !matched {
			continue
		}
		// walk for sign_update
		var found string
		_ = filepath.Walk(filepath.Join(ddBase, e.Name()), func(path string, info os.FileInfo, err error) error {
			if err != nil || found != "" {
				return nil
			}
			if !info.IsDir() && info.Name() == "sign_update" {
				found = path
			}
			return nil
		})
		if found != "" {
			return found, nil
		}
	}
	return "", fmt.Errorf("sign_update not found in DerivedData — build the project in Xcode first")
}

// ─── App info ────────────────────────────────────────────────────────────────

type AppInfo struct {
	Version string
	Build   string
}

func readAppInfo(appPath string) (*AppInfo, error) {
	plist := filepath.Join(appPath, "Contents", "Info.plist")
	if _, err := os.Stat(plist); err != nil {
		return nil, fmt.Errorf("Info.plist not found at %s", plist)
	}
	get := func(key string) (string, error) {
		out, err := exec.Command("plutil", "-extract", key, "raw", plist).Output()
		if err != nil {
			return "", fmt.Errorf("plutil extract %s: %w", key, err)
		}
		return strings.TrimSpace(string(out)), nil
	}
	version, err := get("CFBundleShortVersionString")
	if err != nil {
		return nil, err
	}
	build, err := get("CFBundleVersion")
	if err != nil {
		return nil, err
	}
	return &AppInfo{Version: version, Build: build}, nil
}

// ─── Appcast ─────────────────────────────────────────────────────────────────

type Item struct {
	XMLName        xml.Name `xml:"item"`
	Title          string   `xml:"title"`
	PubDate        string   `xml:"pubDate"`
	SparkleVersion string   `xml:"http://www.andymatuschak.org/xml-namespaces/sparkle version"`
	ShortVersion   string   `xml:"http://www.andymatuschak.org/xml-namespaces/sparkle shortVersionString"`
	MinOS          string   `xml:"http://www.andymatuschak.org/xml-namespaces/sparkle minimumSystemVersion"`
	Description    CDATASect `xml:"description"`
	Enclosure      Enclosure `xml:"enclosure"`
}

type CDATASect struct {
	Value string `xml:",cdata"`
}

type Enclosure struct {
	URL          string `xml:"url,attr"`
	Type         string `xml:"type,attr"`
	EdSignature  string `xml:"http://www.andymatuschak.org/xml-namespaces/sparkle edSignature,attr"`
	Length       string `xml:"length,attr"`
}

func buildEnclosureURL(repo, version, dmgName string) string {
	return fmt.Sprintf("https://github.com/%s/releases/download/v%s/%s", repo, version, dmgName)
}

func buildNotesCDATA(notes []string) string {
	var sb strings.Builder
	sb.WriteString("<ul>")
	for _, n := range notes {
		sb.WriteString("<li>")
		sb.WriteString(n)
		sb.WriteString("</li>")
	}
	sb.WriteString("</ul>")
	return sb.String()
}

// prependItem inserts a new <item> block right after the opening <channel> tag
// (or after the last <language> tag), preserving all existing content verbatim.
func prependItem(appcastPath string, item Item) error {
	raw, err := os.ReadFile(appcastPath)
	if err != nil {
		return err
	}
	content := string(raw)

	// Render the item XML
	var buf bytes.Buffer
	enc := xml.NewEncoder(&buf)
	enc.Indent("    ", "  ")
	if err := enc.Encode(item); err != nil {
		return fmt.Errorf("encoding item: %w", err)
	}
	itemXML := "\n    " + strings.TrimSpace(buf.String()) + "\n"

	// Insert after <!-- Releases are prepended here by the release CLI --> comment if present,
	// otherwise after <language> tag, otherwise after <description> tag.
	markers := []string{
		"<!-- Releases are prepended here by the release CLI -->",
		"</language>",
		"</description>",
	}
	inserted := false
	for _, marker := range markers {
		idx := strings.Index(content, marker)
		if idx >= 0 {
			insertAt := idx + len(marker)
			content = content[:insertAt] + itemXML + content[insertAt:]
			inserted = true
			break
		}
	}
	if !inserted {
		return fmt.Errorf("could not find insertion point in appcast.xml")
	}
	return os.WriteFile(appcastPath, []byte(content), 0644)
}

func buildExists(appcastPath, build string) bool {
	data, err := os.ReadFile(appcastPath)
	if err != nil {
		return false
	}
	return strings.Contains(string(data), ">"+build+"<")
}

// ─── Shell helpers ───────────────────────────────────────────────────────────

func run(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func output(name string, args ...string) (string, error) {
	out, err := exec.Command(name, args...).Output()
	return strings.TrimSpace(string(out)), err
}

// ─── Interactive input ────────────────────────────────────────────────────────

var reader = bufio.NewReader(os.Stdin)

func prompt(msg string) string {
	fmt.Print(msg)
	line, _ := reader.ReadString('\n')
	return strings.TrimSpace(line)
}

func collectNotes() []string {
	fmt.Println("\nEnter release notes (one bullet per line, empty line to finish):")
	var notes []string
	for {
		line := prompt("  • ")
		if line == "" {
			break
		}
		notes = append(notes, line)
	}
	return notes
}

// ─── Main ────────────────────────────────────────────────────────────────────

func main() {
	fmt.Println("╔══════════════════════════════════╗")
	fmt.Println("║   Illuminate Release CLI  🚀     ║")
	fmt.Println("╚══════════════════════════════════╝")

	// 1. Load config
	cfg, repoRoot, err := loadConfig()
	if err != nil {
		fatalf("Config error: %v", err)
	}
	fmt.Printf("\n✓ Config loaded from %s\n", repoRoot)
	fmt.Printf("  App: %s  |  Repo: %s  |  Branch: %s\n", cfg.AppName, cfg.GithubRepo, cfg.GitBranch)

	// 2. Check tools
	fmt.Println("\nChecking required tools…")
	for _, tool := range []string{"create-dmg", "gh", "git"} {
		if err := requireTool(tool); err != nil {
			fatalf("%v", err)
		}
		fmt.Printf("  ✓ %s\n", tool)
	}
	signUpdate, err := findSignUpdate(cfg.DerivedDataPrefixes)
	if err != nil {
		fatalf("%v", err)
	}
	fmt.Printf("  ✓ sign_update: %s\n", signUpdate)

	// 3. Locate exported app
	appPath := filepath.Join(os.Getenv("HOME"), "Downloads", cfg.BundleName)
	if _, err := os.Stat(appPath); err != nil {
		fatalf("Exported app not found at %s\n  → Archive and export via Xcode first", appPath)
	}
	info, err := readAppInfo(appPath)
	if err != nil {
		fatalf("Reading app info: %v", err)
	}
	fmt.Printf("\n✓ Found %s  version %s  (build %s)\n", cfg.BundleName, info.Version, info.Build)

	// 4. Warn on duplicate build
	appcastPath := filepath.Join(repoRoot, cfg.AppcastFile)
	if buildExists(appcastPath, info.Build) {
		fmt.Printf("\n⚠️  Build %s already exists in appcast.xml.\n", info.Build)
		if strings.ToLower(prompt("   Continue anyway? [y/N]: ")) != "y" {
			fmt.Println("Aborted.")
			os.Exit(0)
		}
	}

	// 5. Release notes
	notes := collectNotes()
	if len(notes) == 0 {
		fatalf("No release notes provided — aborting")
	}
	notesText := "- " + strings.Join(notes, "\n- ")

	// 6. Summary + confirmation
	fmt.Printf(`
┌─────────────────────────────────────────────────┐
│  Release Summary                                │
├─────────────────────────────────────────────────┤
│  Version : %-36s│
│  Build   : %-36s│
│  Tag     : %-36s│
│  DMG     : ~/Downloads/%-27s│
│  Repo    : %-36s│
│  Branch  : %-36s│
├─────────────────────────────────────────────────┤
│  Notes:                                         │
`,
		info.Version, info.Build, "v"+info.Version,
		cfg.DMGName, cfg.GithubRepo, cfg.GitBranch)
	for _, n := range notes {
		fmt.Printf("│    • %-43s│\n", n)
	}
	fmt.Println("└─────────────────────────────────────────────────┘")

	if strings.ToLower(prompt("\nProceed? [y/N]: ")) != "y" {
		fmt.Println("Aborted.")
		os.Exit(0)
	}

	dmgPath := filepath.Join(os.Getenv("HOME"), "Downloads", cfg.DMGName)

	// 7. Create DMG
	fmt.Println("\n▶ Creating DMG…")
	if err := os.Remove(dmgPath); err != nil && !os.IsNotExist(err) {
		fatalf("Cannot remove old DMG: %v", err)
	}
	if err := run("create-dmg",
		"--volname", cfg.AppName,
		"--window-pos", "200", "120",
		"--window-size", "660", "400",
		"--icon-size", "160",
		"--icon", cfg.BundleName, "180", "170",
		"--app-drop-link", "480", "170",
		"--hide-extension", cfg.BundleName,
		dmgPath,
		appPath,
	); err != nil {
		fatalf("create-dmg failed: %v", err)
	}
	fmt.Println("  ✓ DMG created")

	// 8. Sign DMG with Sparkle
	fmt.Println("\n▶ Signing DMG with Sparkle…")
	signOut, err := output(signUpdate, dmgPath)
	if err != nil {
		fatalf("sign_update failed: %v", err)
	}
	fmt.Printf("  sign_update output:\n  %s\n", signOut)

	// Parse sparkle:edSignature="..." length="..."
	edSig := extractAttr(signOut, `sparkle:edSignature="`, `"`)
	length := extractAttr(signOut, `length="`, `"`)
	if edSig == "" || length == "" {
		fatalf("Could not parse sign_update output:\n%s", signOut)
	}
	fmt.Printf("  ✓ edSignature: %s\n  ✓ length: %s\n", edSig, length)

	// 9. Update appcast.xml
	fmt.Println("\n▶ Updating appcast.xml…")
	pubDate := time.Now().UTC().Format("Mon, 02 Jan 2006 15:04:05 +0000")
	item := Item{
		Title:          fmt.Sprintf("Version %s (Build %s)", info.Version, info.Build),
		PubDate:        pubDate,
		SparkleVersion: info.Build,
		ShortVersion:   info.Version,
		MinOS:          cfg.MinSystemVersion,
		Description:    CDATASect{Value: buildNotesCDATA(notes)},
		Enclosure: Enclosure{
			URL:         buildEnclosureURL(cfg.GithubRepo, info.Version, cfg.DMGName),
			Type:        "application/octet-stream",
			EdSignature: edSig,
			Length:      length,
		},
	}
	if err := prependItem(appcastPath, item); err != nil {
		fatalf("Updating appcast: %v", err)
	}
	fmt.Println("  ✓ appcast.xml updated")

	// 10. Commit and push appcast
	fmt.Println("\n▶ Committing and pushing appcast…")
	if err := run("git", "-C", repoRoot, "add", cfg.AppcastFile); err != nil {
		fatalf("git add: %v", err)
	}
	commitMsg := fmt.Sprintf("Release v%s appcast", info.Version)
	if err := run("git", "-C", repoRoot, "commit", "-m", commitMsg); err != nil {
		fatalf("git commit: %v", err)
	}
	if err := run("git", "-C", repoRoot, "push", "origin", cfg.GitBranch); err != nil {
		fatalf("git push: %v", err)
	}
	fmt.Println("  ✓ appcast pushed")

	// 11. Create GitHub release
	fmt.Println("\n▶ Creating GitHub release…")
	tag := "v" + info.Version
	if err := run("gh", "release", "create", tag,
		dmgPath,
		"--repo", cfg.GithubRepo,
		"--title", tag,
		"--notes", notesText,
	); err != nil {
		fatalf("gh release create: %v", err)
	}

	fmt.Printf("\n✅  Released %s v%s successfully!\n", cfg.AppName, info.Version)
	fmt.Printf("   GitHub: https://github.com/%s/releases/tag/%s\n", cfg.GithubRepo, tag)
	fmt.Printf("   Appcast: https://raw.githubusercontent.com/%s/%s/%s\n",
		cfg.GithubRepo, cfg.GitBranch, cfg.AppcastFile)
}

func extractAttr(s, prefix, suffix string) string {
	i := strings.Index(s, prefix)
	if i < 0 {
		return ""
	}
	s = s[i+len(prefix):]
	j := strings.Index(s, suffix)
	if j < 0 {
		return ""
	}
	return s[:j]
}

func fatalf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "\n❌  "+format+"\n", args...)
	os.Exit(1)
}
