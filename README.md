# Flashcards - CSV generator

A simple generator of flashcard HTML pages. The data lives in a plain CSV file,
and `build.ps1` turns it into a self-contained `*.html` (no server, no build step,
no libraries - just double-click it in any browser).

The front of a card shows a word; a click **flips the card in 3D** and reveals the
text on the back. You can mark cards as learned.

---

## Quick start

1. Open `cards.csv` and fill in your words and texts (one row per card).
2. Double-click **`build.bat`** (it builds every set).
3. Open the resulting **`cards.html`** in a browser.

> Edit `cards.csv`, open the built `cards.html`.
> `template.html` on its own is just the scaffold - it holds no data.

---

## Files in this folder

| File | Role |
|------|------|
| `cards.csv` | **Data.** Header + one row per card. This is the only file you edit. |
| `template.html` | The scaffold with the markers `/*CARDS_PLACEHOLDER*/`, `/*SET_ID*/`, `/*SET_NAME*/`. |
| `build.ps1` | The builder: CSV -> injected into the template -> `<name>.html`. |
| `build.bat` | Launches `build.ps1` on a double-click. |
| `cards.html` | **The result** - this is what you open (created by the build). |

---

## CSV format

The first row is the header, then one row per card:

```
front;back
Word 1;Text 1
Word 2;Text 2
```

- **Columns.** Matched by name: front - `front` / `word` / `term`; back - `back` /
  `text` / `definition` / `translation` / `meaning`. If none match, the first two
  columns are used.
- **Delimiter.** `;` or `,` - auto-detected. Force it with `-Delimiter ","`.
- **Encoding.** Auto-detected: UTF-8 (with or without BOM) and the system ANSI code
  page (e.g. Windows-1251, what a localized Excel writes) both work without flags.
  Force it if needed: `-Encoding UTF8` or `-Encoding ANSI`.
- **Card count.** Not fixed: as many data rows as the CSV has, that many cards.
  The grid adapts to the screen width.

---

## Multiple sets

One CSV = one set of cards = one HTML file.

To make another set, **copy `cards.csv`** and name it after the topic, e.g.
`english.csv` or `history.csv`, edit it and run `build.bat` again.

`build.ps1` with no parameters builds **all** `*.csv` in the folder, each to its
own file:

```
cards.csv    ->  cards.html
english.csv  ->  english.html
history.csv  ->  history.html
```

The set name goes into the page title, and each set's "learned" progress is
**separate** (stored per file name) - sets do not interfere with each other.

Build just one set:

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1 -Csv english.csv
```

---

## Marking cards as learned

- Each card has a **check** button in the corner. Clicking it marks the card as
  learned (and does not flip it). Click again to unmark.
- A learned card is dimmed and gets a green border.
- At the top of the page: a **"Learned X / N"** counter, a **"Hide learned"**
  toggle and a **"Reset progress"** button.
- Progress is stored in the browser's `localStorage` (per set) - it **survives a
  page reload**.

> The memory is tied to the browser and the file path. Open the same `cards.html`
> in a different browser, or move the file, and its progress starts fresh there.

---

## `build.ps1` parameters

All optional:

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `-Csv` | *(empty)* | A specific CSV. Empty = build every `*.csv` in the folder. |
| `-Out` | *(empty)* | Output name. Empty = `<csv-name>.html`. Ignored when building multiple sets. |
| `-Template` | `template.html` | The template file. |
| `-Delimiter` | *(auto)* | CSV delimiter: `;` or `,`. |
| `-Encoding` | `Auto` | `Auto` / `UTF8` / `ANSI` / `1251` / `Unicode`. |

Example:

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1 -Csv a.csv -Out result.html -Delimiter "," -Encoding UTF8
```

---

## Changing the look of the cards

Edit `template.html` (the CSS at the top of the file):

- card size - `.card { height: 150px }`;
- column width / count - `.grid { ... minmax(180px, 1fr) }` (below 180 = more columns);
- front / back colors - `.front` and `.back`;
- "learned" color - the `#16a34a` value in the `.card.learned ...` and `.learn-btn` rules.

After editing the template, just rebuild (`build.bat`).

---

## FAQ / troubleshooting

- **Card text shows as garbled characters.** The CSV is in an unusual encoding.
  Auto-detection covers UTF-8 and the system ANSI code page; if it is something
  else, set it explicitly, e.g. `-Encoding UTF8`, and rebuild.

- **Excel saved the CSV and something is off.** The "CSV (comma delimited)" option
  in a localized Excel writes ANSI with a `;` delimiter - that is supported
  automatically. Or save as "CSV UTF-8".

- **`build.bat` flashed and closed / the script won't run.** Run it by hand and
  read the message:
  `powershell -ExecutionPolicy Bypass -File build.ps1`

- **You edited `build.ps1` and non-ASCII text broke.** Keep the script ASCII, or
  save it as **UTF-8 with BOM** (Windows PowerShell 5.1 otherwise reads `.ps1` as
  ANSI).
