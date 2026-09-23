# WordClip Help

**English** · [简体中文](HELP.zh-Hans.md) · [繁體中文](HELP.zh-Hant.md)

<!-- Keep this file in sync with the `help.*` keys in
     WordClip/Resources/Localizable.xcstrings — HelpView.swift duplicates this
     content in the app, and there is no build-time link between the two. -->

WordClip is a word-saving and review tool for **macOS and iOS/iPadOS**: select a word in any app and save it in one keystroke, look it up in a bundled 50,000-word English–Chinese dictionary, and review it with SM-2 spaced repetition.

---

## Core concepts

| Name | What it is |
|------|------------|
| **Word list** | The words you've saved to study, with familiarity, review progress, and favorites |
| **Dictionary** | The reference lexicon for lookups — 50,000 built-in ECDICT words, importable for more |
| **Word pack** | A ready-made set of words by difficulty or topic. Import one and start studying; it stays in its own group, separate from what you save yourself |

---

## On macOS

### Select to capture (the main feature)
1. Select an English word in **any app** — a browser, a PDF, your mail client.
2. Press the **capture shortcut** (`⌥⌘C` by default, changeable under Settings → Selection Capture).
3. A HUD confirms "Collected" on screen and the word lands in your word list.

> The first time, authorize WordClip under **System Settings → Privacy & Security → Accessibility** so it can read the selected text.

### OCR capture (Pro)
Also captures words from images, PDFs, video, and text you can't select:

1. Press the **OCR capture shortcut** (`⌥⌘O` by default, changeable under Settings → OCR Capture).
2. The screen dims — **drag to select** the region to recognize, much like the system's `⌘⇧4`.
3. A picker lists the words it found, already checked against the built-in dictionary and filtered of phonetic noise.
4. Tick one or several, then click **Collect**.

> The first time, authorize WordClip under **System Settings → Privacy & Security → Screen Recording**. Restart the app after granting it.

### Word packs
Don't want to build a list from scratch? Import a ready-made pack:

- **Graded**: Beginner (Zhongkao), Gaokao, CET-4, CET-6, Postgraduate Entrance Exam, TOEFL, IELTS, GRE
- **Topical**: Daily Life, Travel & Leisure, Tech English, Business

How to use them:
1. **While your word list is empty**, the pack prompt appears at every launch — tick the packs you want and import.
2. After that, reopen it any time from the **"Word Packs…" button in the word list or Review toolbar** to import more.
3. Imported words are **isolated by group** from the words you save yourself. The group picker at the **top of Review** or in the **word list toolbar** lets you study a single pack, or pick "All" to mix.
4. Packs you already have are marked "Added"; importing again won't create duplicates.
5. **Removing a pack**: filter the word list's group to that pack, click "Remove This Pack" and confirm — that deletes all of the pack's words and their review progress. You can import it again later.

> Every pack is **free and offline**; no network needed. Imported words enter the study queue as brand-new words.

### The menu bar icon
The bookmark icon in the menu bar shows today's overview, **enables or disables selection capture**, and opens the main window. It dims when capture is off. (OCR capture is independent and unaffected by that switch.)

### Keyboard shortcuts
| Shortcut | What it does |
|----------|--------------|
| `⌘1` / `⌘2` / `⌘3` | Switch between Wordbook / Review / Stats |
| `⌘,` | Open Settings |
| `⌘F` or `⌘K` | Focus the search field |
| `⌘N` | Add a word |
| `⌘L` | Speak the selected word |
| `⌘D` | Favorite / unfavorite |
| `⌘R` | Repair the definition |
| `⌘⌫` | Delete the selected word |
| `↑` / `↓` | Move between words |
| `⌘E` | (Menu bar) enable / disable selection capture |
| `⌘/` | Show the shortcut cheat sheet |
| `Space` while studying | Flip to the definition |
| `←` / `→` while studying | Don't know / Know it |

---

## On iOS / iPadOS

- **Add a word**: the `+` at the top right of the word list — type it or paste from the clipboard.
- **Settings**: the gear icon at the top right of the word list.
- **iPad**: the same two-column "list + detail" layout as macOS. With a keyboard attached, the shortcuts work too.
- **iPhone**: tap a word to open its detail, then use back at the top left.

---

## Search and dictionary lookup

Press `⌘F` in the word list (or click the search field) and type:

- **Wordbook** matches appear on top.
- **Dictionary (not saved)** matches appear below — tap one to read its definition and "Add to Wordbook" in one step.

---

## Importing a custom dictionary

> **What it's for: extra definition sources when looking words up. It does not add words to your list.** To add study entries in bulk, use word packs.

**Settings → Dictionaries → Import Dictionary…** takes two formats:

### 1. CSV
One row per word: `word,definition[,phonetic]`, comma- or tab-separated. A header row is optional:

```csv
word,definition,phonetic
serendipity,n. 意外发现珍宝的运气,ˌserənˈdɪpɪti
ephemeral,a. 短暂的,ɪˈfem(ə)rəl
```

### 2. SQLite (with an `entries` table)
Any SQLite file containing an `entries(word, definition, ...)` table imports directly.

> **Stock ECDICT SQLite won't import as-is** — its table is called `stardict` and the Chinese sits in a `translation` column, so it has to be converted to this app's `entries` shape first. `data/build_dictionary.py` in this repo does exactly that:
> ```bash
> cd data && python3 build_dictionary.py --output ecdict-full.sqlite      # all ~770k words
> python3 build_dictionary.py --top 100000 --output ecdict-100k.sqlite    # or the top 100k
> ```
> The resulting `.sqlite` imports here. ECDICT is MIT-licensed.

**Several dictionaries stack in order, and the built-in one wins.** Each can be enabled, disabled, or deleted on its own.

> ⚠️ Import only dictionary files you have the right to use. The app distributes no third-party commercial dictionary.

---

## Review

Review is built on the **SM-2 spaced repetition algorithm**: flip the card, read the definition, mark "Know it" or "Don't know", and the next review is scheduled for you.

### The three states a word can be in

Every word in your list falls into one of three review states, distinguished by badge color:

| State | Badge | Meaning |
|-------|-------|---------|
| **New** | Green | Not yet marked known — either just saved, or always marked "Don't know" |
| **Due** | Orange | Reviewed at least once, and it's time to review again |
| Fresh | None | Reviewed, but the next review is still far off — nothing to do |

> ⚠️ As long as you keep marking a word "Don't know", it **stays green and New** — the algorithm doesn't consider it learned yet. That's SM-2 by design, not a bug.

### SM-2 in one line

**"Know it" stretches the interval further and further; "Don't know" sends it back to the start:**

- **Know it** → the interval grows (1 day → 6 days → then multiplied by an ease factor), so well-known words nag you less and less and cost the fewest reviews.
- **Don't know** → the interval resets to tomorrow to rebuild the memory.

> For the algorithm itself, see the [SuperMemo SM-2 description](https://super-memory.com/english/ol/sm2.htm). WordClip's review engine sits behind a protocol, so upgrading to the more modern FSRS later is a smooth change.

---

## URL scheme

WordClip registers the `wordclip://` scheme, callable from Shortcuts, scripts, and other apps.

### `wordclip://collect?word=<word>`
Saves the given word to your list, filling in the definition from the dictionary automatically.

**Example:**
```
wordclip://collect?word=serendipity
```

- macOS: saved in the background with a HUD confirmation, without interrupting the app you're in.
- iOS: pairs well with Shortcuts automations.

> To test from the command line on macOS: `open "wordclip://collect?word=serendipity"`
> (The system may ask for confirmation the first time — click "Open".)

---

## Backing up your data

**Settings → Data**:

- **Export Vocabulary**: exports the words you **saved yourself** as a JSON backup, learning progress included. **Free.**
- **Import Vocabulary**: restores them on a new device, merged by word without overwriting progress you already have. **Pro.**

> Word pack words stay out of backups — they can be re-imported on the new device at any time, so there's no reason to carry their bulk.

---

## WordClip Pro

WordClip is a **one-time purchase, unlocked for life**. No subscription, no auto-renewal.

| Feature | Free | Pro |
|---------|:----:|:---:|
| Capture (selection / URL scheme / paste) | ✅ | ✅ |
| Built-in offline dictionary (phonetics, definitions, speech) | ✅ | ✅ |
| Word list, review, stats, review reminders | ✅ | ✅ |
| Exporting a vocabulary backup | ✅ | ✅ |
| **OCR capture** (recognize words in a screen region) | ❌ | ✅ |
| **Importing a vocabulary** | ❌ | ✅ |
| **iCloud sync across devices** | ❌ | ✅ |

- **To upgrade**: Settings → Account → "Upgrade to WordClip Pro".
- **iCloud sync** is still in development — the switch in Settings is a placeholder and doesn't work yet.
- After changing devices or reinstalling, tap "Restore Purchase" on the paywall to get Pro back.

---

## FAQ

**Q: The capture shortcut does nothing?**
Check two things: whether Accessibility is granted in System Settings, and whether "Enable Selection Capture" is on under Settings → Selection Capture. (OCR capture is independent and unaffected by that switch.)

**Q: A word shows "No definition yet"?**
The dictionary may not have been ready when it was saved. Opening the word list fills it in automatically; you can also select the word and press `⌘R` to repair it by hand.

**Q: My imported dictionary isn't working?**
Make sure that dictionary's switch is turned on under Settings → Dictionaries.
