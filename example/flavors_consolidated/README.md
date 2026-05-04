# example_with_flavors_consolidated

A Flutter project showcasing the consolidated single-file flavors config (`flutter_launcher_icons_flavors.yaml`).

Unlike the legacy `example/flavors/` setup which uses one yaml per flavor, this example defines all flavors in a single file with shared `defaults` and per-flavor overrides.

## How to run this project

Before being able to run this example you need to navigate to this directory and run the following command

```
flutter create .
```

This project has the following flavors:

- production: `flutter run --flavor production`
- development: `flutter run --flavor development`
- integration: `flutter run --flavor integration`

## Generating icons

```
flutter pub run flutter_launcher_icons
```

The tool auto-discovers `flutter_launcher_icons_flavors.yaml` and generates icons for every flavor listed under `flavors:`.
