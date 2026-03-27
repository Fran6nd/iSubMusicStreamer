---
name: Swift Migration Progress
description: Completed phases and remaining work for ObjC→Swift migration
type: project
---

## Completed migrations

### Phase C (Cache/Folders/Albums/Songs/Bookmarks tabs)
- C1: FolderDropdownControl → Swift
- C2: AlbumViewController → Swift
- C3: GenresArtistViewController → Swift
- C4: GenresAlbumViewController → Swift
- C5.0: AllAlbumsViewController → Swift
- C5.1: AllSongsViewController → Swift
- C5.2: CacheOfflineFoldersViewController → Swift
- C5.3: FoldersViewController → Swift
- C5.4: BookmarksViewController → Swift
- C5.5: CacheAlbumViewController → Swift
- C5.6: CacheViewController → Swift

**Why:** Systematic ObjC→Swift modernization of all tab view controllers.
**How to apply:** Follow same patterns when migrating remaining ObjC VCs.

## Recurring pitfalls (save time on next migrations)
- pbxproj Python script: always manually verify group listing AND both Sources phases are wired after running
- `FMDatabaseQueue` variadic methods (`intForQuery:`, `stringForQuery:`) don't bridge → use `inDatabase` + `executeQuery`
- `NSString.md5` is a property (no parens), needs NSString cast: `NSString.md5(str)`
- `BytesForSecondsAtBitrate(s, b)` macro → `(b / 8) * 1024 * s`
- `startSongAtOffsetInBytes:andSeconds:` → `startSongAtOffset(inBytes:andSeconds:)`
- `kReachabilityChangedNotification` not bridged → use `"kNetworkReachabilityChangedNotification"`
- `isEqualToSong:` → `isEqual(to:)`
- `executeQuery(_:withArgumentsInArray:)` → `executeQuery(_:withArgumentsIn:)`
- When migrating a class that another ObjC .m imports, remove `#import "MigratedClass.h"` from that .m
- `sectionInfoFromTable:inDatabaseQueue:withColumn:` → `sectionInfo(fromTable:in:FMDatabaseQueue:withColumn:)`
- `sectionInfoFromTable:inDatabase:withColumn:` → `sectionInfo(fromTable:in:FMDatabase:withColumn:)`

## Remaining ObjC view controllers (approximate)
- Various settings, player, home, playlists VCs
- CacheViewController was the last Cache tab VC
