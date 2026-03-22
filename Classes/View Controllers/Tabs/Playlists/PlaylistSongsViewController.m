//
//  PlaylistSongsViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlaylistSongsViewController.h"
#import "ServerListViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "NSMutableURLRequest+SUS.h"
#import "ViewObjectsSingleton.h"
#import "Defines.h"
#import "RXMLElement.h"
#import "FMDatabaseQueueAdditions.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "JukeboxSingleton.h"
#import "NSError+ISMSError.h"
#import "ISMSSong+DAO.h"
#import "SUSServerPlaylist.h"
#import "EX2Kit.h"
#import "Swift.h"
#import "SUSLoader.h"

LOG_LEVEL_ISUB_DEFAULT

@interface PlaylistSongsViewController()
@property (strong) NSURLSessionDataTask *dataTask;
@property (strong) UIView *uploadBannerView;
@end

@implementation PlaylistSongsViewController

- (BOOL)isLocalPlaylist {
    return self.serverPlaylist == nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (self.isLocalPlaylist) {
		self.title = [databaseS.localPlaylistsDbQueue stringForQuery:@"SELECT playlist FROM localPlaylists WHERE md5 = ?", self.md5];

		if (!settingsS.isOfflineMode) {
			UIView *uploadView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];

			UILabel *sendLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
			sendLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
			sendLabel.backgroundColor = [UIColor clearColor];
            sendLabel.textColor = UIColor.labelColor;
			sendLabel.textAlignment = NSTextAlignmentCenter;
			sendLabel.font = [UIFont boldSystemFontOfSize:24];
			sendLabel.text = @"Save to Server";
			[uploadView addSubview:sendLabel];

			UIButton *sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
			sendButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
			sendButton.frame = CGRectMake(0, 0, 320, 50);
			[sendButton addTarget:self action:@selector(uploadPlaylistAction:) forControlEvents:UIControlEventTouchUpInside];
			[uploadView addSubview:sendButton];

			self.uploadBannerView = uploadView;
		}
	} else {
        self.title = self.serverPlaylist.playlistName;
        self.playlistCount = [databaseS.localPlaylistsDbQueue intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM splaylist%@", self.md5]];
        [self updatePlaylistHeader];
		[self.tableView reloadData];

        // Add the pull to refresh view
        __weak PlaylistSongsViewController *weakSelf = self;
        self.refreshControl = [[RefreshControl alloc] initWithHandler:^{
            [weakSelf loadData];
        }];
	}

    self.tableView.rowHeight = Defines.rowHeight;
    [self.tableView registerClass:UniversalTableViewCell.class forCellReuseIdentifier:UniversalTableViewCell.reuseId];
}

- (void)updatePlaylistHeader {
    NSString *name = self.title ?: @"";
    NSUInteger count = self.playlistCount;

    // Collect up to 4 cover art IDs from the first 4 songs
    NSMutableArray<NSString *> *artIds = [NSMutableArray arrayWithCapacity:4];
    NSString *tableName = [NSString stringWithFormat:@"%@%@", self.isLocalPlaylist ? @"playlist" : @"splaylist", self.md5];
    for (NSUInteger i = 0; i < MIN(count, 4); i++) {
        ISMSSong *song = self.isLocalPlaylist
            ? [ISMSSong songFromDbRow:i inTable:tableName inDatabaseQueue:databaseS.localPlaylistsDbQueue]
            : [ISMSSong songFromServerPlaylistId:self.md5 row:i];
        if (song.coverArtId) {
            [artIds addObject:song.coverArtId];
        }
    }

    __weak PlaylistSongsViewController *weakSelf = self;

    PlaylistHeaderView *header = [[PlaylistHeaderView alloc] init];
    header.playlistName = name;
    header.songCount = (NSInteger)count;
    header.coverArtIds = artIds;

    header.onPlayAll = ^{
        [weakSelf playAllSongs];
    };
    header.onShuffle = ^{
        [weakSelf shuffleSongs];
    };

    // Build a container that also includes the upload banner for local playlists
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.tableHeaderView = container;
    [NSLayoutConstraint activateConstraints:@[
        [container.centerXAnchor constraintEqualToAnchor:self.tableView.centerXAnchor],
        [container.widthAnchor constraintEqualToAnchor:self.tableView.widthAnchor],
        [container.topAnchor constraintEqualToAnchor:self.tableView.topAnchor]
    ]];

    [container addSubview:header];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [header.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [header.topAnchor constraintEqualToAnchor:container.topAnchor],
        [header.heightAnchor constraintEqualToConstant:PlaylistHeaderView.height]
    ]];

    UIView *bottomAnchorView = header;
    if (self.uploadBannerView) {
        UIView *uploadBanner = self.uploadBannerView;
        [container addSubview:uploadBanner];
        uploadBanner.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [uploadBanner.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [uploadBanner.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
            [uploadBanner.topAnchor constraintEqualToAnchor:header.bottomAnchor],
            [uploadBanner.heightAnchor constraintEqualToConstant:50]
        ]];
        bottomAnchorView = uploadBanner;
    }

    [bottomAnchorView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor].active = YES;

    [self.tableView.tableHeaderView layoutIfNeeded];
    self.tableView.tableHeaderView = self.tableView.tableHeaderView;
}

- (void)playAllSongs {
    if (settingsS.isJukeboxEnabled) {
        [databaseS resetJukeboxPlaylist];
        [jukeboxS clearRemotePlaylist];
    } else {
        [databaseS resetCurrentPlaylistDb];
    }
    playlistS.isShuffle = NO;
    [self loadPlaylistIntoCurrentPlaylist];
    if (settingsS.isJukeboxEnabled) {
        [jukeboxS replacePlaylistWithLocal];
    }
    [musicS playSongAtPosition:0];
}

- (void)shuffleSongs {
    if (settingsS.isJukeboxEnabled) {
        [databaseS resetJukeboxPlaylist];
        [jukeboxS clearRemotePlaylist];
    } else {
        [databaseS resetCurrentPlaylistDb];
    }
    playlistS.isShuffle = YES;
    [self loadPlaylistIntoCurrentPlaylist];
    if (settingsS.isJukeboxEnabled) {
        [jukeboxS replacePlaylistWithLocal];
    }
    [musicS playSongAtPosition:0];
}

- (void)loadPlaylistIntoCurrentPlaylist {
    NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
    NSString *currTableName = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
    NSString *playTableName = [NSString stringWithFormat:@"%@%@", self.isLocalPlaylist ? @"playlist" : @"splaylist", self.md5];
    [databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"ATTACH DATABASE ? AS ?", [databaseS.databaseFolderPath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
        if ([db hadError]) { DDLogError(@"[PlaylistSongsViewController] Err attaching the currentPlaylistDb %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
        [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ SELECT * FROM %@", currTableName, playTableName]];
        [db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
    }];
}

- (void)loadData {
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:n2N(self.serverPlaylist.playlistId) forKey:@"id"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getPlaylist" parameters:parameters];
    self.dataTask = [SUSLoader.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            [EX2Dispatch runInMainThreadAsync:^{
                if (settingsS.isPopupsEnabled) {
                    NSString *message = [NSString stringWithFormat:@"There was an error loading the playlist.\n\nError %li: %@", (long)error.code, error.localizedDescription];
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                    [self presentViewController:alert animated:YES completion:nil];
                }
                
                self.tableView.scrollEnabled = YES;
                [viewObjectsS hideLoadingScreen];
                [self.refreshControl endRefreshing];
            }];
        } else {
            RXMLElement *root = [[RXMLElement alloc] initFromXMLData:data];
            if (!root.isValid) {
                //NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
                // TODO: Handle this error
            } else {
                RXMLElement *error = [root child:@"error"];
                if (error.isValid) {
                    //NSString *code = [error attribute:@"code"];
                    //NSString *message = [error attribute:@"message"];
                    //[self subsonicErrorCode:[code intValue] message:message];
                    // TODO: Handle this error
                } else {
                    // TODO: Handle !isValid case
                    if ([[root child:@"playlist"] isValid]) {
                        [databaseS removeServerPlaylistTable:self.md5];
                        [databaseS createServerPlaylistTable:self.md5];
                        [root iterate:@"playlist.entry" usingBlock:^(RXMLElement *e) {
                            ISMSSong *aSong = [[ISMSSong alloc] initWithRXMLElement:e];
                            [aSong insertIntoServerPlaylistWithPlaylistId:self.md5];
                        }];
                    }
                }
            }
            
            self.playlistCount = [databaseS.localPlaylistsDbQueue intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM splaylist%@", self.md5]];

            [EX2Dispatch runInMainThreadAsync:^{
                [self updatePlaylistHeader];
                [self.tableView reloadData];
                [self.refreshControl endRefreshing];
                [viewObjectsS hideLoadingScreen];
                self.tableView.scrollEnabled = YES;
            }];
        }
    }];
    [self.dataTask resume];
    
    self.tableView.scrollEnabled = NO;
    [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
}	

- (void)cancelLoad {
    [self.dataTask cancel];
    self.dataTask = nil;
	self.tableView.scrollEnabled = YES;
	[viewObjectsS hideLoadingScreen];
	
	if (!self.isLocalPlaylist) {
        [self.refreshControl endRefreshing];
	}
}

- (void)viewWillAppear:(BOOL)animated  {
    [super viewWillAppear:animated];
    
    // For some reason this controller needs to do this, but none of the others do :/
//    self.navigationController.navigationBar.translucent = NO;
	
	if(musicS.showPlayerIcon) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:Defines.musicNoteImageSystemName] style:UIBarButtonItemStylePlain target:self action:@selector(nowPlayingAction:)];
	} else {
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	if (self.isLocalPlaylist) {
		self.playlistCount = [databaseS.localPlaylistsDbQueue intForQuery:[NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", self.md5]];
        [self updatePlaylistHeader];
		[self.tableView reloadData];
	} else {
		if (self.playlistCount == 0) {
			[self loadData];
		}
	}
}

- (void) settingsAction:(id)sender  {
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
}


- (IBAction)nowPlayingAction:(id)sender {
    PlayerViewController *playerViewController = [[PlayerViewController alloc] init];
    playerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:playerViewController animated:YES];
}

- (void)uploadPlaylistAction:(id)sender {
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:n2N(self.title), @"name", nil];
    
	NSString *query = [NSString stringWithFormat:@"SELECT COUNT(*) FROM playlist%@", self.md5];
	NSUInteger count = [databaseS.localPlaylistsDbQueue intForQuery:query];
	NSMutableArray *songIds = [NSMutableArray arrayWithCapacity:count];
	for (int i = 1; i <= count; i++) {
		@autoreleasepool {
			NSString *query = [NSString stringWithFormat:@"SELECT songId FROM playlist%@ WHERE ROWID = %i", self.md5, i];
			NSString *songId = [databaseS.localPlaylistsDbQueue stringForQuery:query];
			
			[songIds addObject:n2N(songId)];
		}
	}
	[parameters setObject:[NSArray arrayWithArray:songIds] forKey:@"songId"];
	
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"createPlaylist" parameters:parameters];
    self.dataTask = [SUSLoader.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            if (settingsS.isPopupsEnabled) {
                [EX2Dispatch runInMainThreadAsync:^{
                    NSString *message = [NSString stringWithFormat:@"There was an error saving the playlist to the server.\n\nError %li: %@", (long)error.code, error.localizedDescription];
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:message preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                    [self presentViewController:alert animated:YES completion:nil];
                }];
            }
        } else {
            DDLogVerbose(@"[PlaylistSongsViewController] upload playlist response: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            RXMLElement *root = [[RXMLElement alloc] initFromXMLData:data];
            if (!root.isValid) {
                NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NotXML];
                [self subsonicErrorCode:nil message:error.description];
            } else {
                RXMLElement *error = [root child:@"error"];
                if (error.isValid) {
                    NSString *code = [error attribute:@"code"];
                    NSString *message = [error attribute:@"message"];
                    [self subsonicErrorCode:code message:message];
                }
            }
        }
        
        [EX2Dispatch runInMainThreadAsync:^{
            self.tableView.scrollEnabled = YES;
            [viewObjectsS hideLoadingScreen];
            [self.refreshControl endRefreshing];
        }];
    }];
    [self.dataTask resume];
    
    self.tableView.scrollEnabled = NO;
    [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
}

- (void)subsonicErrorCode:(NSString *)errorCode message:(NSString *)message {
    DDLogError(@"[PlayistSongsViewController] subsonic error %@: %@", errorCode, message);
    if (settingsS.isPopupsEnabled) {
        [EX2Dispatch runInMainThreadAsync:^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Subsonic Error" message:message preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }];
    }
}

#pragma mark Table view methods

- (ISMSSong *)songAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isLocalPlaylist) {
        return [ISMSSong songFromDbRow:indexPath.row inTable:[NSString stringWithFormat:@"playlist%@", self.md5] inDatabaseQueue:databaseS.localPlaylistsDbQueue];
    } else {
        return [ISMSSong songFromServerPlaylistId:self.md5 row:indexPath.row];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.playlistCount;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UniversalTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UniversalTableViewCell.reuseId];
    cell.hideNumberLabel = NO;
    cell.hideCoverArt = NO;
    cell.hideDurationLabel = NO;
    cell.hideSecondaryLabel = NO;
    cell.number = indexPath.row + 1;
    ISMSSong *song = [self songAtIndexPath:indexPath];
    [cell updateWithModel:song];
    if (!song.isVideo) {
        [cell configureSongContextMenuWithSong:song presenter:self];
    }
    return cell;
}

- (void)didSelectRowInternal:(NSIndexPath *)indexPath {
	// Clear the current playlist
	if (settingsS.isJukeboxEnabled) {
		[databaseS resetJukeboxPlaylist];
		[jukeboxS clearRemotePlaylist];
	} else {
		[databaseS resetCurrentPlaylistDb];
	}
	
	playlistS.isShuffle = NO;
	
	/*for (int i = 0; i < self.playlistCount; i++)
	{
		@autoreleasepool
		{
			ISMSSong *aSong;
			if (self.isLocalPlaylist)
			{
				aSong = [ISMSSong songFromDbRow:i inTable:[NSString stringWithFormat:@"playlist%@", self.md5] inDatabaseQueue:databaseS.localPlaylistsDbQueue];
			}
			else
			{
				aSong = [ISMSSong songFromServerPlaylistId:self.md5 row:i];
			}
			
			[aSong addToCurrentPlaylistDbQueue];
		}
	}*/
	
	// Need to do this for speed (NOTE: haha well 10 years ago maybe, but probably not now)
	NSString *databaseName = settingsS.isOfflineMode ? @"offlineCurrentPlaylist.db" : [NSString stringWithFormat:@"%@currentPlaylist.db", [settingsS.urlString md5]];
	NSString *currTableName = settingsS.isJukeboxEnabled ? @"jukeboxCurrentPlaylist" : @"currentPlaylist";
	NSString *playTableName = [NSString stringWithFormat:@"%@%@", self.isLocalPlaylist ? @"playlist" : @"splaylist", self.md5];
	[databaseS.localPlaylistsDbQueue inDatabase:^(FMDatabase *db) {
		 [db executeUpdate:@"ATTACH DATABASE ? AS ?", [databaseS.databaseFolderPath stringByAppendingPathComponent:databaseName], @"currentPlaylistDb"];
		 if ([db hadError]) { DDLogError(@"[PlaylistSongsViewController] Err attaching the currentPlaylistDb %d: %@", [db lastErrorCode], [db lastErrorMessage]); }
		 
		 [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ SELECT * FROM %@", currTableName, playTableName]];
		 [db executeUpdate:@"DETACH DATABASE currentPlaylistDb"];
	 }];
	
    if (settingsS.isJukeboxEnabled) {
		[jukeboxS replacePlaylistWithLocal];
    }

    [viewObjectsS hideLoadingScreen];
    
    [musicS playSongAtPosition:indexPath.row];
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath  {
	if (!indexPath) return;
    
    [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
    [self performSelector:@selector(didSelectRowInternal:) withObject:indexPath afterDelay:0.05];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    ISMSSong *song = [self songAtIndexPath:indexPath];
    if (!song.isVideo) {
        return [SwipeAction downloadAndQueueConfigWithModel:song];
    }
    return nil;
}

@end
