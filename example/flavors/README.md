# example_with_flavors

A Flutter project demonstrating the **legacy** per-flavor configuration layout (one `flutter_launcher_icons-<flavor>.yaml` file per flavor).

> For new projects prefer the **consolidated** layout shown in [`../flavors_consolidated`](../flavors_consolidated). Both layouts are supported in 0.15.x; the consolidated layout takes precedence when both are present. Run `dart run flutter_launcher_icons_flavors migrate` to convert legacy files into the consolidated format automatically.

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

Build a single flavor or all of them:

```shell
dart run flutter_launcher_icons_flavors generate --flavor development
dart run flutter_launcher_icons_flavors generate --all-flavors
```
