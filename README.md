# Rootle

Dig up where words come from. A gamified etymology app for Mac and iPhone, with home-screen and desktop widgets.

- **Dig Site**: a learning path that runs down through soil layers. Each layer is a themed unit (Shapeshifters, Gods & Monsters, The Spice Road, Raiders' Hoard…) with two lessons and a treasure review.
- **Word of the Day**: a new word each day, the same on every device. Add it to your lexicon for +5 XP.
- **Exercises**: new-word cards, meaning, "dig deeper" (original meaning), where-from, roots, build-the-word, time travel (put a word's ancestors in order), fact or fib (including myth-busting), and match-up.
- **Lexicon**: every word you've dug up, with a chart of the languages they come from and spaced-repetition strength.
- **Grove**: your streak as a growing plant, a weekly XP chart, badges, daily goal and a daily word reminder.
- **Widgets**: Word of the Day (small, medium, large, plus Lock Screen on iPhone) and Streak Plant.

## Build

```bash
xcodegen generate
open Rootle.xcodeproj
```

Pick the **Rootle-iOS** or **Rootle-macOS** scheme. Signing uses team `62LTV4PK7X`.

## Content

80 hand-checked words ship in `Shared/Resources/lexicon-*.json`. Beyond those, the lexicon keeps growing with Claude (`claude-opus-5-5`, see `App/Engine/WordForge.swift`):

- **Dig deeper** at the bottom of the dig site makes a new themed layer of 8 words. When you reach the deepest layer, the next one is dug automatically.
- **Dig up another word** under the word of the day adds extra words to today's finds (+3 XP each when you add them).
- When fewer than 5 unseen words are left, a fresh batch of 6 is generated in the background, so the word of the day never runs out.

Generated words are saved in `generated-lexicon.json` in the app group container, so the widget sees them. Each day's word is pinned once shown, so the list can grow without reshuffling past days.

### Guess first

A new word of the day or extra find asks one multiple-choice question before showing its story: what it first meant, or which language it came from (+2 XP for a right guess). The answer stays hidden on the home screen until you've guessed.

## Sync

Grove → Sync with iCloud Drive → Choose folder. Pick the same iCloud Drive folder (e.g. `Rootle`) on every device. Each device writes only `progress-<device>.json` and `words-<device>.json` there and reads the others', so nothing is overwritten. `ProgressState.merged(with:)` combines them: per-device XP tallies add up, streaks come from the union of active days, word memory keeps the most practised copy, and "Reset progress" wins over anything older. This works with a free developer team (CloudKit needs a paid one).

### API key

```bash
./scripts/write_secrets.sh
```

This reads `ANTHROPIC_API_KEY` (from the environment or `~/.zsh_secrets`) into the git-ignored `Config/Secrets.xcconfig`, which is built into the app's Info.plist. Rebuild after running it. Without a key the app still works with the bundled words.

## Art

Raw illustrations are in `art/raw`. Run `python3 scripts/build_assets.py` to rebuild the asset catalog and app icons.

## Debug

Debug builds only:

- `-seedDemo` fills in about two weeks of fake progress.
- Mac: run the binary with `-snapshot` (add `-snapshotNarrow` for 820pt too) to print each screen in light and dark as base64 PNGs, or with `-forgeTest` to generate one real layer and print it.
