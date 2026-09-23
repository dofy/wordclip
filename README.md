# WordClip

**English** · [简体中文](README.zh-Hans.md) · [繁體中文](README.zh-Hant.md)

A cross-platform vocabulary tool for collecting words anywhere, looking them up offline, and reviewing them with spaced repetition. Built for English today; the architecture extends to any language.

**Platforms**: macOS · iOS · iPadOS
**Stack**: SwiftUI (one codebase, all platforms) · SwiftData · a Swift package (`WordClipKit`, the shared core) · GRDB (offline dictionary)

---

## What's built

### Capture
- **Global capture on macOS**: select a word in any app, press the hotkey (`⌥⌘C` by default), and it's saved — a HUD confirms on screen without interrupting the app you're in. It reads the selection through Accessibility and never touches the clipboard.
- **OCR capture (Pro)**: press the hotkey (`⌥⌘O` by default), drag to select a screen region, and Vision recognizes the words in it. Candidates are checked against the built-in dictionary, then you multi-select from a picker. Works on images, PDFs, and text you can't select.
- **Menu bar icon**: today's overview, a quick toggle for selection capture, and a way to open the main window. The icon dims when capture is off.
- **URL scheme**: `wordclip://collect?word=<word>` — call it from Shortcuts, a script, or another app.
- **iOS / iPadOS**: add words by typing them or pasting from the clipboard.

### Word packs
- **Two kinds of offline pack**: graded (Beginner / Gaokao / CET-4 / CET-6 / Postgraduate / TOEFL / IELTS / GRE) and topical (Daily Life / Travel & Leisure / Tech English / Business). All free, all offline.
- **Folder-style isolation**: imported words stay separate from the ones you save yourself. Review and the word list can filter by group, so you can study one pack or pick "All" and mix.
- **Removable**: filter the word list to a pack and remove it in one step — that drops the pack's entries and their review progress, and you can import it again later.
- **Where to find them**: an empty library prompts you at every launch, and the word list and Review toolbars let you import more at any time.

### Dictionary and lookup
- **Built-in offline dictionary**: a trimmed ECDICT with roughly 50,000 words (phonetics plus Chinese and English glosses), shipped in the bundle as a GRDB SQLite file.
- **Lemmatization**: inflected forms such as `brought → bring` resolve to the base form for lookup.
- **Custom dictionary import**: adds definition *sources* for lookups — it does not add words to your list. Takes CSV and ECDICT-shaped SQLite, stacks several dictionaries by priority, and lets you enable, disable, delete, and reorder them. The app includes format notes and a preparation guide.
- **Structured definitions**: one line per part of speech, discipline tags (`[计]`, `[化]`) greyed out, Chinese and English glosses in separate sections. Which gloss leads depends on your UI language.

### Word list
- **Three-column layout** (macOS / iPad): navigation → list → detail.
- **Search**: matches from your list come first, with unsaved dictionary matches below — tap one to preview it and save it.
- **Group filter**: once a pack is imported, a group menu appears in the toolbar for viewing one pack, your manual entries, or everything.
- **Sorting**: by date added, alphabetically, or by familiarity. Your choice is remembered.
- Favorites, text-to-speech, definition repair, delete.
- **A full set of keyboard shortcuts** (macOS, and iPad with a keyboard): navigation, search, add and delete, speak, favorite, and more.

### Review
- **SM-2 spaced repetition**: flip the card, mark "Know it" or "Don't know" — knowing it stretches the next interval, not knowing it resets to tomorrow, and reviews are scheduled for you.
- Flipping is one-way (so a stray tap can't undo it). While studying, `Space` flips and `←` / `→` grade.
- Badges in the word list distinguish "New" from "Due".
- **A local notification** reminds you to review each day.

### Stats and data
- A stats panel: total words, due, new, and mastery rate.
- **JSON backup import / export**: exports the words you saved yourself (pack words can simply be imported again, so they stay out of backups). Import merges by word and won't overwrite learning progress you already have.

### Paid features
- **The WordClip Pro paywall**: a single "lifetime purchase" screen (which unlocks OCR capture and dictionary import).
- **Feature gating**: the free/Pro boundary runs through `entitlement.isPro` everywhere. DEBUG builds use `MockEntitlement` (with a "Simulate Pro" switch in Settings) and Release builds use the real `StoreKitEntitlement`, swapped behind the `AppEntitlement` alias.
- **StoreKit 2 in-app purchase (shipped)**: `StoreKitEntitlement` (one-time, non-consumable) plus a local `.storekit` configuration, so Run in Xcode is enough to test purchase and restore without a paid account. Shipping still needs the product configured in App Store Connect and verified on device.
- **Free**: capture, basic offline lookup, the word list, review, stats, export. **Pro**: OCR capture, dictionary import.

### Also
- **A trilingual interface**: English / 简体中文 / 繁體中文 via String Catalogs, following the system language. UI language is independent of the language you're studying.
- **Placeholder iCloud sync UI**: a switch in Settings; real sync is planned, not built.
- **70 `WordClipKit` unit tests** covering the algorithm, dictionary, import, stats, entitlement, and word packs.

---

## Planned

> **Pricing (decided)**: a one-time purchase, unlocked for life. No subscription. **WordClip Pro** covers OCR capture and dictionary import, plus the planned iCloud sync and online dictionary. Capture and basic lookup are free forever. See [PLAN.md](docs/PLAN.md#5-收费政策已定).

- **iCloud sync**: SwiftData + CloudKit across devices. The Settings UI is already in place; the sync itself needs building, and a paid Apple Developer account.
- **An online dictionary service**: search and import extended dictionaries directly instead of only local files. Local CSV / SQLite import stays as a fallback.
- **An iOS Share Extension**: capture from the system share sheet.
- **More review modes**: Chinese → English spelling, listening comprehension, and others. Today it's flip-card know / don't-know only.
- **AI enhancements**: definitions, example sentences, and root-word explanations. The `AIProvider` protocol is in place with a placeholder implementation.
- **Other study languages**, Japanese among them. Capture logic currently assumes English.

---

## Documentation

- [Help](HELP.md) — usage, shortcuts, dictionary import, the URL scheme
- [Progress](docs/PROGRESS.md) — what's built and what's next
- [Plan](docs/PLAN.md) — product goals, scope, pricing
- [Architecture and key technical decisions](docs/ARCHITECTURE.md)

## Development setup

- macOS with **the full Xcode** — Command Line Tools alone can't build the app
- `brew install xcodegen`. `*.xcodeproj` is not in the repo, so run `xcodegen generate` after cloning
- An Apple Developer account for on-device debugging and distribution

## Distribution

- **iOS / iPadOS**: the App Store. See [RELEASE-iOS.md](docs/RELEASE-iOS.md).
- **macOS**: Developer ID, notarized, distributed from the site — **not the Mac App Store**, because the sandbox forbids reading another app's selected text and that would cost us native global capture. See [ARCHITECTURE §3.1](docs/ARCHITECTURE.md) and [PLAN](docs/PLAN.md).
