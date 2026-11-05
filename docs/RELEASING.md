# Releasing Nata

## Two numbers

| | Example | Who sets it | Seen by |
|---|---|---|---|
| **Version name** | `1.0.57` | Codemagic: `MAJOR.MINOR` from `pubspec.yaml`, then the build number | Users, in the stores |
| **Build number** | `57` | Codemagic, automatically | The stores only |

`pubspec.yaml` holds `version: 1.0.0+1`. Codemagic keeps its `MAJOR.MINOR`
(`1.0`) and puts the build number last, so **every store build raises the
version by itself**: 1.0.57, then 1.0.58, for testing and production alike.
Nothing is committed back. iOS and Android count build numbers separately,
so the same code can be 1.0.12 on iOS and 1.0.57 on Android.

## Builds for testers (TestFlight, Google Play internal testing)

Merge to `main`. Codemagic builds the next version (1.0.<next build
number>). Nothing else to do.

## A store release (App Store, Google Play production)

Start the **iOS – App Store (production)** or **Android – Google Play
(production)** workflow in Codemagic on `main`. It builds the next version
(1.0.<next build number>) by itself: no tag or commit needed.

### Raising MAJOR or MINOR

For a bigger step (1.0.x to 1.1.x or 2.0.x), from an up-to-date `main`:

```bash
bash scripts/release.sh patch
```

- `minor` for new features (1.2.x → 1.3.x)
- `major` for big changes (1.2.x → 2.0.x)
- `patch` is no longer needed: the build number is the last part
- or an exact version: `bash scripts/release.sh 1.4.0`

It changes `pubspec.yaml`, commits "Release 1.2.4" and tags `v1.2.4`. Then
push both (or add `--push` to the command above):

```bash
git push origin main v1.2.4
```

The tag starts the App Store and Google Play production builds, as
`1.3.<next build number>`. A tag that doesn't match `pubspec.yaml` fails at
once, so always tag through the script.

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
