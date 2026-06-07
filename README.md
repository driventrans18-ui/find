# Sleuth

A native **SwiftUI iOS app** that checks whether a **username** has a public
profile across a list of supported sites — the same core idea as the
open-source [Sherlock](https://github.com/sherlock-project/sherlock) project.

> **What this is — and isn't.** Sleuth searches by *username* (a handle a person
> chose and made public), not by face or photo. It does **not** do facial
> recognition, scrape private data, or bypass logins. It only requests the same
> public profile URLs you could open in a browser. Use it responsibly and within
> each site's Terms of Service — not to stalk, harass, or dox anyone.

## Features

- Enter a username and probe ~30 sites concurrently
- Live progress and a list of found public profiles, tap to open
- Search history persisted locally (UserDefaults)
- Site list is plain JSON data (`Resources/sites.json`) — easy to extend

## Project layout

```
Sleuth/
  project.yml                 # XcodeGen project definition
  Resources/
    sites.json                # the site catalog (name, url, detection rule)
    Assets.xcassets/          # app icon
  Sources/
    SleuthApp.swift           # @main entry point
    Models/                   # SiteTarget, SearchResult
    Services/                 # SiteCatalog, UsernameChecker (networking), HistoryStore
    Views/                    # SwiftUI screens + SearchViewModel
```

## Build & run

This repo stores the project as a readable `project.yml` rather than a binary
`.xcodeproj`. Generate the Xcode project with [XcodeGen](https://github.com/yonyz/XcodeGen):

```bash
brew install xcodegen
cd Sleuth
xcodegen generate
open Sleuth.xcodeproj
```

Then pick a simulator and hit **Run**. (You can also create a new iOS App in
Xcode manually and drag the `Sources/` and `Resources/` folders in.)

> Set your signing **Team** in the target's *Signing & Capabilities* tab before
> running on a physical device.

## Adding a site

Append an entry to `Resources/sites.json`:

```json
{
  "name": "Example",
  "category": "Social",
  "url": "https://example.com/{}",
  "detection": "status_code"
}
```

- `url` — public profile URL with `{}` as the username placeholder.
- `probe_url` (optional) — a lighter endpoint to request instead of `url`
  (e.g. a JSON API). The `url` is still what gets opened on a match.
- `detection`:
  - `"status_code"` — account exists when the request returns 2xx.
  - `"message"` — account is **absent** when `error_message` appears in the body.
- `error_message` — required for `"message"` detection.

## How detection works

`UsernameChecker` sends a request per site concurrently (HEAD for status-code
sites, GET for message sites), with a browser-like User-Agent. Results stream
back to the UI as each site responds. Detection rules can break when sites
change their markup and anti-bot measures may cause false negatives — treat
results as hints, not proof.
