# iSubMusicStreamer — Swift Migration & Playlist Feature Plan

> Written: 2026-03-23
> Covers: GUI structure audit, parenting inconsistencies, full Swift migration roadmap,
> and new playlist features (create server playlist, clone local↔server, add songs to server playlist).

---

## Part 1 — GUI Structure & Parenting Audit

### Current Hierarchy (correct)

```
UIWindow
└── CustomUITabBarController          ← Swift, owns mini player
    ├── UINavigationController (×N)   ← Swift, one per tab
    │   └── <Tab Root VC>             ← mostly Objective-C
    └── MiniPlayerView                ← Swift, pinned above tab bar
```

The mini player lives in `CustomUITabBarController.view`, constrained
`bottom == view.bottom − tabBar.height`. This is correct after the recent
reparenting work. `additionalSafeAreaInsets` propagates the 64 pt reservation
down the full VC stack automatically.

---

### Inconsistencies Found

#### 1. Dead Objective-C files — `CustomUINavigationController`

`CustomUINavigationController.h` and `.m` still sit in the project even
though the Swift replacement is active and the header was removed from the
bridging header. They are unreachable but pollute the project.

**Fix:** Remove both files from the Xcode project and disk.

---

#### 2. `isHidden` / `alpha` duality on MiniPlayerView

In `CustomUITabBarController`:

- `animateMiniPlayerVisibility` animates **`alpha`** (0 → 1).
- `viewDidLayoutSubviews` checks `!miniPlayerView.isHidden` to decide whether
  to apply the 64 pt bottom inset.

If `isHidden == false` but `alpha == 0` (no song playing), `viewDidLayoutSubviews`
incorrectly applies the inset on every layout pass — adding phantom bottom space
to all content VCs before the first song ever plays.

**Fix:** Replace the alpha animation with an `isHidden` toggle, OR gate the
inset calculation on `alpha > 0` / a separate `hasSong` boolean. The transform-based
nav-transition animation can keep its own path.

---

#### 3. `AppDelegate` manually declares one `UINavigationController` property per tab

```objc
@property UINavigationController *homeNavigationController;
@property UINavigationController *playlistsNavigationController;
// … 8 more
```

These are set by the AppDelegate at launch and are never refreshed. The tab bar
controller's `viewControllers` array is the single source of truth; these
properties are stale duplicates that diverge if tabs are ever reordered.

**Fix:** Remove the per-tab nav controller properties from the AppDelegate.
Consumers should retrieve `tabBarController.viewControllers[index]` or use
typed accessors on `CustomUITabBarController`.

---

#### 4. `ViewObjectsSingleton` duplicates tab bar controller state

`ViewObjectsSingleton` calls `orderMainTabBarController()` and tracks tab
state in Objective-C alongside the Swift `CustomUITabBarController`. As more
logic moves to Swift, there will be two owners for tab bar configuration.

**Fix:** Long-term, absorb `orderMainTabBarController` logic directly into
`CustomUITabBarController.viewDidLoad`. Remove the singleton dependency once
fully migrated.

---

#### 5. `PlaylistsViewController` uses XIB layout; all new VCs are programmatic

`PlaylistsViewController.xib` and `PlaylistSongsViewController.xib` are the
last remaining XIB-based tab VCs. Every other recently written Swift VC is
fully programmatic. The XIBs contain no real layout (just a plain table view)
and add friction when migrating.

**Fix:** During the playlist rewrite (Phase 3), build purely programmatic Swift
VCs and delete the XIBs.

---

#### 6. `PlaylistSongsViewController` uses a raw `md5` string to identify local playlists

```objc
@property (copy) NSString *md5;            // local playlist
@property (copy) SUSServerPlaylist *serverPlaylist;   // server playlist
```

One VC, two separate identity systems, with branching logic inside. This is
fragile and hides whether a playlist is local or server-scoped.

**Fix:** Rewrite as a Swift VC that takes a typed `Playlist` enum:
```swift
enum PlaylistSource {
    case local(ISMSLocalPlaylist)
    case server(ServerPlaylist)
}
```

---

#### 7. `AddToPlaylistViewController` bypasses the DAO layer

The Swift file queries SQLite directly using raw `executeQuery` strings inside
the VC itself. This duplicates logic that should belong to a `LocalPlaylistDAO`.

**Fix:** Extract all DB access into a `LocalPlaylistDAO` (Swift struct/class)
and have `AddToPlaylistViewController` call only that.

---

#### 8. No server playlist mutation support in the DAO

`SUSServerPlaylistsDAO` exposes only a `serverPlaylists: NSArray` read property
and a `loader`. There is no API for:
- Creating a new server playlist
- Renaming or deleting a server playlist
- Adding songs to an existing server playlist

**Fix:** Extend the DAO (or write a new Swift `ServerPlaylistService`) with
full CRUD via Subsonic API calls (`createPlaylist`, `updatePlaylist`, `deletePlaylist`).

---

## Part 2 — Swift Migration Roadmap

Migration follows a bottom-up, layer-by-layer order: models before DAOs,
DAOs before VCs, shared singletons last (after all callers are Swift).
Each phase ends with a working, shippable build.

---

### Phase 1 — Cleanup & Foundation  *(~1 week)*

Goal: remove dead code and establish Swift patterns.

| Task | File(s) |
|------|---------|
| Delete dead `CustomUINavigationController.h/.m` | `Classes/Custom UI/` |
| Fix `isHidden`/`alpha` duality on MiniPlayerView | `CustomUITabBarController.swift` |
| Remove per-tab nav controller properties from AppDelegate | `iSubAppDelegate.h/.m` |
| Add `CustomUITabBarController` typed tab accessors to replace AppDelegate nav props | `CustomUITabBarController.swift` |
| Extract `LocalPlaylistDAO.swift` from inline SQL in `AddToPlaylistViewController` | new file |
| Write unit tests for `LocalPlaylistDAO` | new test file |

---

### Phase 2 — Core Models in Swift  *(~2 weeks)*

Rewrite as pure Swift value types with no Objective-C dependencies. Keep
`NS_SWIFT_NAME` aliases in the old headers during transition so bridged
callers compile.

| Model | Replacement | Notes |
|-------|-------------|-------|
| `ISMSSong` | `Song.swift` struct | Already aliased; add Codable |
| `ISMSAlbum` | `Album.swift` struct | |
| `ISMSArtist` | `Artist.swift` struct | |
| `ISMSLocalPlaylist` | `LocalPlaylist.swift` struct | |
| `SUSServerPlaylist` | Already has `NS_SWIFT_NAME(ServerPlaylist)` | Rewrite body in Swift |
| `ISMSServer` | `Server.swift` struct | |

Each struct conforms to `Identifiable`, `Hashable`, and `Codable`.
The Objective-C `@interface` stays as a thin `@objc` wrapper until all
callers are Swift, then is deleted.

---

### Phase 3 — Playlist System Rewrite  *(~2–3 weeks)*

This is the highest user-visible priority and is detailed in Part 3 below.

| Task |
|------|
| `LocalPlaylistDAO.swift` — full CRUD |
| `ServerPlaylistService.swift` — full CRUD via Subsonic API |
| `PlaylistsViewController.swift` — programmatic, replaces XIB version |
| `PlaylistSongsViewController.swift` — typed `PlaylistSource`, replaces XIB version |
| `AddToPlaylistViewController` — updated to support server playlists |

---

### Phase 4 — Remaining Tab View Controllers  *(~3 weeks)*

Migrate one tab per sub-phase. Each VC is self-contained so migrations are
independent and safe to do in feature branches.

Order (easiest → hardest):

1. `BookmarksViewController`
2. `CacheViewController`
3. `ChatViewController`
4. `GenresViewController`
5. `AllSongsViewController`
6. `AllAlbumsViewController`
7. `FoldersViewController`
8. `HomeViewController` (complex, many child VCs)

---

### Phase 5 — DAOs & Loaders  *(~2 weeks)*

| Layer | Action |
|-------|--------|
| All `SUS*DAO.h/m` | Rewrite as Swift `struct` + `actor` where async fetching needed |
| All `SUS*Loader.h/m` | Replace `SUSLoaderDelegate` callback pattern with `async/await` |
| Remove `SUSLoaderDelegate` protocol | No longer needed once all callers are async/await |

---

### Phase 6 — Singletons → Services  *(~3 weeks)*

Replace global mutable singletons with dependency-injected services, starting
with the ones referenced most from Swift code.

| Singleton | Swift replacement |
|-----------|-------------------|
| `PlaylistSingleton` | `PlaybackQueue` (ObservableObject or actor) |
| `MusicSingleton` | `PlayerService` |
| `CacheSingleton` | `CacheService` |
| `JukeboxSingleton` | `JukeboxService` |
| `SavedSettings` | `AppSettings` (property-wrapped `UserDefaults`) |
| `ViewObjectsSingleton` | Absorbed into `CustomUITabBarController` |
| `DatabaseSingleton` | `DatabaseService` (wrapper around `FMDatabaseQueue`) |

`AudioEngine` (BASS wrappers) stays in Objective-C until a native AVAudioEngine
replacement is viable — it is well-isolated and that migration is a separate project.

---

### Phase 7 — AppDelegate & Scene Lifecycle  *(~1 week)*

- Migrate `iSubAppDelegate` to Swift
- Adopt `UISceneDelegate` / `UIWindowSceneDelegate`
- Delete all remaining bridging header entries

---

## Part 3 — Playlist Feature Plan

### Current State

| Feature | Local | Server |
|---------|-------|--------|
| List playlists | ✅ | ✅ (read-only) |
| View songs in playlist | ✅ | ✅ (read-only) |
| Create new playlist | ✅ (via AddToPlaylist alert) | ❌ |
| Rename playlist | ✅ | ❌ |
| Delete playlist | ✅ | ❌ |
| Add single song | ✅ (`AddToPlaylistViewController`) | ❌ |
| Add multiple songs / reorder | Partial | ❌ |
| Clone local → server | ❌ | — |
| Clone server → local | — | ❌ |

---

### 3.1 — `LocalPlaylistDAO.swift`

Extract all SQL from `AddToPlaylistViewController` and `PlaylistsViewController` into:

```swift
struct LocalPlaylistDAO {
    // Read
    func fetchAll() -> [LocalPlaylist]
    func fetchSongs(in playlist: LocalPlaylist) -> [Song]

    // Write
    func create(named name: String) throws -> LocalPlaylist
    func rename(_ playlist: LocalPlaylist, to name: String) throws
    func delete(_ playlist: LocalPlaylist) throws
    func addSong(_ song: Song, to playlist: LocalPlaylist) throws
    func addSongs(_ songs: [Song], to playlist: LocalPlaylist) throws
    func removeSong(at index: Int, from playlist: LocalPlaylist) throws
    func moveSong(from: Int, to: Int, in playlist: LocalPlaylist) throws
}
```

---

### 3.2 — `ServerPlaylistService.swift`

New Swift actor wrapping Subsonic API endpoints:

```swift
actor ServerPlaylistService {
    // Read
    func fetchAll() async throws -> [ServerPlaylist]
    func fetchSongs(in playlist: ServerPlaylist) async throws -> [Song]

    // Write — Subsonic API
    func create(named name: String, songs: [Song] = []) async throws -> ServerPlaylist
    func addSongs(_ songs: [Song], to playlist: ServerPlaylist) async throws
    func removeSongs(at indices: [Int], from playlist: ServerPlaylist) async throws
    func rename(_ playlist: ServerPlaylist, to name: String) async throws
    func delete(_ playlist: ServerPlaylist) async throws

    // Clone operations (see 3.4)
    func cloneLocalToServer(_ local: LocalPlaylist) async throws -> ServerPlaylist
    func cloneServerToLocal(_ server: ServerPlaylist) async throws -> LocalPlaylist
}
```

Subsonic endpoints used:
- `getPlaylists` — list
- `getPlaylist` — songs in playlist
- `createPlaylist` — create (can include songIds)
- `updatePlaylist` — rename, add songs, remove by index
- `deletePlaylist` — delete

---

### 3.3 — `PlaylistsViewController.swift` (rewrite)

Programmatic Swift replacement for `PlaylistsViewController.h/m` + XIB.

**Structure:**
```
PlaylistsViewController
├── UISegmentedControl  [Local | Server]
├── UITableView
│   ├── Section 0: action row "New Playlist…" (always visible)
│   └── Section 1+: playlist rows with swipe-to-delete and context menus
└── Toolbar (edit mode)
```

**Context menu on each playlist row (long-press / right-click):**
- Rename
- Delete
- Copy to Server (local rows only)
- Copy to Local (server rows only)
- Add all songs to queue

**New playlist creation:**
- **Local:** UIAlertController with text field (existing UX, keep it)
- **Server:** same UIAlertController pattern → calls `ServerPlaylistService.create`

**Loading state:** Use `async/await` + `@MainActor` rather than `SUSLoaderDelegate`.

---

### 3.4 — `PlaylistSongsViewController.swift` (rewrite)

Typed init:

```swift
init(playlist: PlaylistSource)

enum PlaylistSource {
    case local(LocalPlaylist)
    case server(ServerPlaylist)
}
```

**Features for both local and server:**
- Swipe-to-delete song
- "Add all to queue" toolbar button
- Long-press context menu per song: "Add to queue", "Add to playlist…"

**Server-only features (new):**
- Editing mode: reorder rows (calls `updatePlaylist` on commit)
- Remove song from server playlist (calls `updatePlaylist` with `songIndexToRemove`)
- "Add songs" button → push a song search/browse VC that returns songs to add

---

### 3.5 — `AddToPlaylistViewController.swift` (extend)

Currently local-only. Extend to show a segmented control [Local | Server]:

- **Local section:** existing behaviour
- **Server section:** lists server playlists fetched via `ServerPlaylistService`
  - "New server playlist…" row at top
  - Selecting a server playlist calls `ServerPlaylistService.addSongs(_:to:)`

---

### 3.6 — Clone Operations

**Local → Server ("Upload to Server"):**

1. Fetch all songs in the local playlist via `LocalPlaylistDAO.fetchSongs(in:)`
2. Filter to songs that have a `songId` from the current server (skip cached-only songs)
3. Call `ServerPlaylistService.create(named: local.name, songs: filteredSongs)`
4. Show progress HUD; on completion show `SlidingNotification`

**Server → Local ("Save Offline"):**

1. Fetch server playlist songs via `ServerPlaylistService.fetchSongs(in:)`
2. Call `LocalPlaylistDAO.create(named: server.playlistName)`
3. Call `LocalPlaylistDAO.addSongs(_:to:)` for all songs
4. Optionally kick off a cache download for all songs

Both operations are accessible via the context menu on the respective
playlist row in `PlaylistsViewController` and via a toolbar button in
`PlaylistSongsViewController`.

---

## Summary — Dependency Order

```
Phase 1  Cleanup + fix parenting bugs
  ↓
Phase 2  Swift model structs (Song, Album, LocalPlaylist, ServerPlaylist…)
  ↓
Phase 3  LocalPlaylistDAO + ServerPlaylistService + Playlist VCs rewrite
  ↓         (all three playlist features land here)
Phase 4  Remaining tab VCs
  ↓
Phase 5  DAOs & Loaders → async/await
  ↓
Phase 6  Singletons → Services
  ↓
Phase 7  AppDelegate + SceneDelegate
```

Each phase is independently shippable. Phases 4–7 can be parallelised across
feature branches once Phase 3 is merged.
