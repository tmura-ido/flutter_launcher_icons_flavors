# example_with_flavors_consolidated

A Flutter project showcasing the **consolidated** single-file flavors config (`flutter_launcher_icons_flavors.yaml`).

Unlike the legacy [`../flavors`](../flavors) example which uses one yaml per flavor, this example defines all flavors in a single file with shared `defaults` and per-flavor overrides.

## Prerequisites

Before running this example, navigate to this directory and scaffold the platform folders:

```shell
flutter create .
```

## Flavors

This project defines three flavors:

- `production` — `flutter run --flavor production`
- `development` — `flutter run --flavor development`
- `integration` — `flutter run --flavor integration`

## Generating icons

```shell
dart run flutter_launcher_icons_flavors generate --all-flavors
```

Build a single flavor with `--flavor <name>`. With no selector, `generate` builds every flavor declared in `flavors:` (same as `--all-flavors`).
