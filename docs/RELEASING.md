# Releasing Nata

## Two numbers

| | Example | Who sets it | Seen by |
|---|---|---|---|
| **Version name** | `1.2.3` | You, with `scripts/release.sh` | Users, in the stores |
| **Build number** | `57` | Codemagic, automatically | The stores only |

`pubspec.yaml` holds both (`version: 1.2.3+57`). Only the name before the `+`
matters; Codemagic replaces the build number on every store build.

## Builds for testers (TestFlight, Google Play internal testing)

Merge to `main`. Codemagic builds the current version name with the next
build number. Nothing else to do; testers can get several builds of the same
version.

## A store release (App Store, Google Play production)

From an up-to-date `main`:

```bash
bash scripts/release.sh patch
```

- `patch` for fixes (1.2.3 → 1.2.4)
- `minor` for new features (1.2.3 → 1.3.0)
- `major` for big changes (1.2.3 → 2.0.0)
- or an exact version: `bash scripts/release.sh 1.4.0`

It changes `pubspec.yaml`, commits "Release 1.2.4" and tags `v1.2.4`. Then
push both (or add `--push` to the command above):

```bash
git push origin main v1.2.4
```

The tag starts the App Store and Google Play production builds. A tag that
doesn't match `pubspec.yaml` fails at once, so always tag through the script.

## How the build number is picked

Each build asks the store for the highest build number it already has and
uses one more (and never less than Codemagic's own counter):

- **iOS:** the highest of TestFlight and the App Store for "Nata Delivery"
  (Apple ID 6824326148).
- **Android:** the highest version code on any Google Play track. Until the
  Google Play service account is set up, it can't read this and falls back
  to Codemagic's counter.

So testing and production builds never collide, and a bundle uploaded by hand
(like the first Android one, from `scripts/build_play_bundle.sh`) is counted.
If you upload by hand again, give it a build number higher than the store's:
`bash scripts/build_play_bundle.sh 58`.
