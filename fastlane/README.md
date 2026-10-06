fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android build

```sh
[bundle exec] fastlane android build
```

Build a signed release AAB

### android internal

```sh
[bundle exec] fastlane android internal
```

Upload to Google Play Internal Testing

### android beta

```sh
[bundle exec] fastlane android beta
```

Upload to Google Play Closed Testing (Alpha)

### android production

```sh
[bundle exec] fastlane android production
```

Promote Internal Testing release to Production

### android release

```sh
[bundle exec] fastlane android release
```

Bump versionName (bump:patch|minor|major) + versionCode, upload to Internal Testing and tag vX.Y.Z

### android notes

```sh
[bundle exec] fastlane android notes
```

Preview the release notes for the next release

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
