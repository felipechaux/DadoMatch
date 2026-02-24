---
description: How to build a signed release AAB and upload DadoMatch to Google Play Store
---

# Prerequisites

| Item | Status |
|------|--------|
| Android keystore (`app/dadomatch-dev.jks`) | ✅ Generated |
| Signing keys in `local.properties` | ✅ Done |
| `fastlane/Fastfile` + `fastlane/Appfile` | ✅ Done |
| `app/play-service-account.json` | ❌ **You must provide this** |
| App created in Google Play Console | ❓ Confirm with user |

> **Security**: `*.jks`, `*.keystore`, and `play-service-account.json` are in `.gitignore` and will never be committed.

---

## Step 1 — Bump version before every release

In `app/build.gradle.kts`, increment:

```kotlin
versionCode = <previous + 1>   // must be strictly greater than last uploaded
versionName = "1.x.x"
```

---

## Step 2 — Build a signed release AAB

```bash
cd /Applications/Developer/DadoMatch
fastlane build
```

Output: `app/build/outputs/bundle/release/app-release.aab`

---

## Step 3 — Upload to Internal Testing

Place your Google Play service account JSON at `app/play-service-account.json`, then:

```bash
fastlane internal
```

This builds **and** uploads to the **Internal Testing** track automatically.

---

## Step 4 — Promote to Production

Once internal testing is approved:

```bash
fastlane production
```

---

## Step 5 — Commit version bump

```bash
git add app/build.gradle.kts
git commit -m "chore: bump versionCode/versionName for release"
git push
```

---

## Available Fastlane Lanes

| Lane | Command | Description |
|------|---------|-------------|
| `build` | `fastlane build` | Build signed release AAB |
| `internal` | `fastlane internal` | Build + upload to Internal Testing |
| `production` | `fastlane production` | Promote Internal → Production |

---

## Keystore details (dev)

| Field | Value |
|-------|-------|
| File | `app/dadomatch-dev.jks` |
| Alias | `dadomatch-dev` |
| Store password | `dadomatch_dev_2024` |
| Key password | `dadomatch_dev_2024` |
| Validity | 10,000 days |

> ⚠️ For production releases on the Play Store, generate a **separate production keystore** with a strong password and back it up securely outside of the repo.
