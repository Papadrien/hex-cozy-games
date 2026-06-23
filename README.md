# Hex Cozy Games

A relaxing hex-tile placement game built with Flutter & Flame.

## Tech Stack

| Layer | Choice |
|---|---|
| Game engine | [Flame](https://flame-engine.org/) (custom hexagonal grid) |
| State | [Riverpod](https://riverpod.dev/) |
| Database | [Drift](https://drift.simonbinder.eu/) (SQLite) |
| i18n | `flutter_localizations` + ARB files |
| Linter | `very_good_analysis` |
| CI | GitHub Actions (`flutter analyze`, `flutter test`, release build) |

## Getting Started

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter test
flutter run
```

## Project Structure

```
lib/
  core/          Design tokens (colors, constants), i18n strings
  data/          Drift database definition + seed data
  game/          Flame components (grid, tiles, board analysis)
  providers/     Riverpod providers + business logic
  ui/            Flutter screens and widgets
  main.dart      App entry point
```

## Architecture

See `doc/01_contexte_architecture.md` for the full architectural context document.
