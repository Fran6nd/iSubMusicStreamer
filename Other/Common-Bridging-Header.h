//
//  Common-Bridging-Header.h
//  iSub
//
//  Created by Benjamin Baron on 11/11/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

/*
 * Import Objective-C headers here to be exposed to Swift in all build targets
 */

#ifndef Common_Bridging_Header_h
#define Common_Bridging_Header_h

#import "Defines.h"
#import "ObjcExceptionCatcher.h"

/*
 * User Interface Components
 */

// View Controllers
#import "CurrentPlaylistViewController.h"
#import "EqualizerViewController.h"
#import "ServerListViewController.h"
#import "SUSAllAlbumsDAO.h"
#import "SUSAllSongsDAO.h"
#import "SUSAllSongsLoader.h"


/*
 * Data Models
 */

// Loaders
#import "ISMSErrorDomain.h"
#import "NSError+ISMSError.h"
#import "SUSLoader.h"
#import "SUSServerShuffleLoader.h"
#import "SUSQuickAlbumsLoader.h"
#import "SUSStatusLoader.h"

// DAOs
#import "SUSNowPlayingDAO.h"
#import "SUSChatDAO.h"
#import "BassEffectDAO.h"
#import "SUSDropdownFolderLoader.h"
#import "SUSRootFoldersDAO.h"
#import "SUSSubFolderDAO.h"
#import "ISMSSong+DAO.h"
#import "ISMSBookmarkDAO.h"
#import "SUSLyricsDAO.h"
#import "SUSCoverArtDAO.h"

// Models
#import "ISMSArtist.h"
#import "ISMSAlbum.h"
#import "ISMSServer.h"
#import "ISMSLocalPlaylist.h"
#import "SUSServerPlaylist.h"

/*
 * Extensions
 */

#import "GTMNSString+HTML.h"
#import "SUSErrorDomain.h"
#import "NSString+time.h"
#import "NSMutableURLRequest+SUS.h"
#import "UIApplication+Helper.h"
#import "UIDevice+Info.h"
#import "NSString+FileSize.h"

/*
 * Singletons
 */

#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "JukeboxSingleton.h"
#import "SavedSettings.h"
#import "AudioEngine.h"
#import "ISMSStreamManager.h"
#import "DatabaseSingleton.h"
#import "CacheSingleton.h"
#import "ISMSCacheQueueManager.h"

/*
 * Frameworks
 */

#import "RXMLElement.h"
#import "Flurry.h"
#import "FMDatabaseQueueAdditions.h"
#import "FMDatabaseAdditions.h"
#import "GCDWebServer.h"
#import "GCDWebServerDataResponse.h"
#import "GCDWebServerErrorResponse.h"

#endif /* Common_Bridging_Header_h */
