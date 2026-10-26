# Dailynote

English | [中文](README.zh-CN.md)

**Dailynote** is a daily task planner where each day is a blank canvas instead of a list. You put tasks on it as sticky-note cards, connect related cards by bumping them together, and drag a card to the bottom of the screen when it's done. Anything you didn't finish moves to the next day on its own.

I built it for myself, for Windows and Android, from one Flutter codebase.

**[⬇ Download the latest release](https://github.com/826-Leoyu/MyPersonalUseApp/releases/latest)** (Windows zip, Android APK)

> The interface is in Chinese. Dates are shown with English month names, e.g. `Tue, Oct 20, 2026`.

## Why

Most to-do apps give you a vertical list, and the only way to show "do this, then that" or "these belong together" is to reorder rows. Whiteboard apps like Miro or Freeform give you that freedom, but they don't think in days: there's no "done", and nothing moves to tomorrow. Dailynote is a cross between the two: an Apple Notes–style canvas, one page per day, with real task behaviour.

## Features

- **One canvas per day.** Pan and zoom freely on a dot-grid canvas. A date list shows how many open tasks each day has, and you can plan days ahead. Past days are read-only.
- **Task cards.** Each card has a title, an optional note and a resizable size. Pick from 8 soft preset colours or a custom colour. Everything saves automatically.
- **Link cards by bumping them.** Drag one card onto another and hold for about 0.4 s. A preview appears, and you let go to connect them. Bump them again to disconnect. Links are smooth curved arrows that follow the cards.
- **Drag to finish.** While you drag a card, a ✅ Done zone and a 🗑️ Trash zone appear at the bottom. Completed cards go into a per-day history. Deleted cards stay in the trash for 10 days, and restoring one brings its links back.
- **Automatic carry-over.** Unfinished tasks move to today, keeping their layout and links. The original day keeps a faded read-only record, so there's never a duplicate task.
- **Adaptive layout.** One interface for phone and desktop: a slide-out date drawer on narrow screens, a collapsible sidebar on wide ones. Light and dark themes follow the system.
- **Keyboard shortcuts on Windows.** `Ctrl+N` new card, `Enter` edit, `Ctrl+Enter` mark done, `Delete` delete, `←`/`→` change day, `T` jump to today, `Ctrl+0` show all cards, and `Ctrl+Z` undo.
- **Private by design.** All data stays on the device in a local SQLite database. The Android app doesn't even request internet permission, and an automated test guards this.

## Install

| Platform | Steps |
|---|---|
| Windows 10/11 (x64) | Unzip `dailynote-windows-<version>.zip` anywhere and run `Dailynote.exe`. The exe isn't code-signed, so SmartScreen may warn you: click *More info → Run anyway*. |
| Android 7.0+ | Open `dailynote-android-<version>.apk` on the phone and allow "install unknown apps" when asked. |

Data is stored locally and isn't synced between devices.

## How it's built

| | |
|---|---|
| Framework | Flutter / Dart, one codebase for Windows and Android |
| State | Riverpod |
| Storage | Drift (SQLite) |
| Tests | 645 unit and widget tests, run in CI (GitHub Actions) on every push |

The data model is designed so cloud sync can be added later without migrating data. Links already store direction and type, so they can later become task dependencies or a timeline.

The project is spec-driven. Before writing code, requirements were worked out in an interview and turned into a written spec with 56 acceptance criteria. That spec was split into GitHub issues, and each issue was built test-first on its own branch and merged through a reviewed pull request.

### Project layout

```
lib/
  app/         app entry, theme, providers, daily maintenance
  board/       UI: canvas, cards, links, drop zones, date list,
               adaptive layout, completed and trash pages
  planner/     domain logic: carry-over, completion, trash, link rules
  storage/     Drift database
  formatting/  date formatting
test/          widget tests (board/), domain tests (planner/),
               release checks (release/)
docs/          design doc, spec, UI references, release guide (in Chinese)
```

### Run from source

Requires the Flutter stable SDK.

```sh
flutter pub get
flutter test
flutter run -d windows   # or an Android device
```

To build release packages and sign the Android app, see [`docs/RELEASE.md`](docs/RELEASE.md).

## Roadmap

- Cloud sync across devices
- Task dependencies and a timeline with estimated durations
- Subtasks
- iOS version
