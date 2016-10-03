/*****************************************************************************
 * VLCPlaylistInfo.h: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2002-2015 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Benjamin Pracht <bigben at videolan dot org>
 *          Felix Paul Kühne <fkuehne at videolan dot org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

/*****************************************************************************
 * VLCPlaylistInfo interface
 *****************************************************************************/


@interface VLCInfo : NSWindowController

@property (readonly) input_item_t *item;

@property (readwrite, weak) IBOutlet NSOutlineView *outlineView;
@property (readwrite, weak) IBOutlet NSTabView *tabView;

@property (readwrite, weak) IBOutlet NSTextField *uriLabel;
@property (readwrite, weak) IBOutlet NSTextField *titleLabel;
@property (readwrite, weak) IBOutlet NSTextField *authorLabel;
@property (readwrite, weak) IBOutlet NSTextField *uriTextField;
@property (readwrite, weak) IBOutlet NSTextField *titleTextField;
@property (readwrite, weak) IBOutlet NSTextField *authorTextField;
@property (readwrite, weak) IBOutlet NSTextField *collectionLabel;
@property (readwrite, weak) IBOutlet NSTextField *collectionTextField;
@property (readwrite, weak) IBOutlet NSTextField *copyrightLabel;
@property (readwrite, weak) IBOutlet NSTextField *copyrightTextField;
@property (readwrite, weak) IBOutlet NSTextField *dateLabel;
@property (readwrite, weak) IBOutlet NSTextField *dateTextField;
@property (readwrite, weak) IBOutlet NSTextField *descriptionLabel;
@property (readwrite, weak) IBOutlet NSTextField *descriptionTextField;
@property (readwrite, weak) IBOutlet NSTextField *encodedbyLabel;
@property (readwrite, weak) IBOutlet NSTextField *encodedbyTextField;
@property (readwrite, weak) IBOutlet NSTextField *genreLabel;
@property (readwrite, weak) IBOutlet NSTextField *genreTextField;
@property (readwrite, weak) IBOutlet NSTextField *languageLabel;
@property (readwrite, weak) IBOutlet NSTextField *languageTextField;
@property (readwrite, weak) IBOutlet NSTextField *nowPlayingLabel;
@property (readwrite, weak) IBOutlet NSTextField *nowPlayingTextField;
@property (readwrite, weak) IBOutlet NSTextField *publisherLabel;
@property (readwrite, weak) IBOutlet NSTextField *publisherTextField;
@property (readwrite, weak) IBOutlet NSTextField *seqNumLabel;
@property (readwrite, weak) IBOutlet NSTextField *seqNumTextField;
@property (readwrite, weak) IBOutlet NSImageView *imageWell;
@property (readwrite, weak) IBOutlet NSButton *saveMetaDataButton;

@property (readwrite, weak) IBOutlet NSTextField *audioLabel;
@property (readwrite, weak) IBOutlet NSTextField *audioDecodedLabel;
@property (readwrite, weak) IBOutlet NSTextField *audioDecodedTextField;
@property (readwrite, weak) IBOutlet NSTextField *demuxBitrateLabel;
@property (readwrite, weak) IBOutlet NSTextField *demuxBitrateTextField;
@property (readwrite, weak) IBOutlet NSTextField *demuxBytesLabel;
@property (readwrite, weak) IBOutlet NSTextField *demuxBytesTextField;
@property (readwrite, weak) IBOutlet NSTextField *displayedLabel;
@property (readwrite, weak) IBOutlet NSTextField *displayedTextField;
@property (readwrite, weak) IBOutlet NSTextField *inputBitrateLabel;
@property (readwrite, weak) IBOutlet NSTextField *inputBitrateTextField;
@property (readwrite, weak) IBOutlet NSTextField *inputLabel;
@property (readwrite, weak) IBOutlet NSTextField *lostAudioBuffersLabel;
@property (readwrite, weak) IBOutlet NSTextField *lostAudioBuffersTextField;
@property (readwrite, weak) IBOutlet NSTextField *lostFramesLabel;
@property (readwrite, weak) IBOutlet NSTextField *lostFramesTextField;
@property (readwrite, weak) IBOutlet NSTextField *playedAudioBuffersLabel;
@property (readwrite, weak) IBOutlet NSTextField *playedAudioBuffersTextField;
@property (readwrite, weak) IBOutlet NSTextField *readBytesLabel;
@property (readwrite, weak) IBOutlet NSTextField *readBytesTextField;
@property (readwrite, weak) IBOutlet NSTextField *sentBitrateLabel;
@property (readwrite, weak) IBOutlet NSTextField *sentBitrateTextField;
@property (readwrite, weak) IBOutlet NSTextField *sentBytesLabel;
@property (readwrite, weak) IBOutlet NSTextField *sentBytesTextField;
@property (readwrite, weak) IBOutlet NSTextField *sentPacketsLabel;
@property (readwrite, weak) IBOutlet NSTextField *sentPacketsTextField;
@property (readwrite, weak) IBOutlet NSTextField *soutLabel;
@property (readwrite, weak) IBOutlet NSTextField *videoLabel;
@property (readwrite, weak) IBOutlet NSTextField *videoDecodedLabel;
@property (readwrite, weak) IBOutlet NSTextField *videoDecodedTextField;

- (void)updateCocoaWindowLevel:(NSInteger)i_level;
- (IBAction)toggleWindow:(id)sender;

- (IBAction)metaFieldChanged:(id)sender;
- (IBAction)saveMetaData:(id)sender;
- (IBAction)downloadCoverArt:(id)sender;

- (void)updatePanelWithItem:(input_item_t *)_p_item;

- (void)updateMetadata;
- (void)updateStatistics;

@end

/**
 * Holds information for one element in the codec information panel
 */
@interface VLCInfoTreeItem : NSObject

@property (readwrite) NSString *name;
@property (readwrite) NSString *value;

@property (readwrite) NSArray *children;

@end
