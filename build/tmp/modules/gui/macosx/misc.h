/*****************************************************************************
 * misc.h: code not specific to vlc
 *****************************************************************************
 * Copyright (C) 2003-2014 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Jon Lech Johansen <jon-vl@nanocrew.net>
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

#import <Cocoa/Cocoa.h>

/*****************************************************************************
 * NSSound (VLCAdditions)
 *
 * added code to change the system volume, needed for the apple remote code
 * this is simplified code, which won't let you set the exact volume
 * (that's what the audio output is for after all), but just the system volume
 * in steps of 1/16 (matching the default AR or volume key implementation).
 *****************************************************************************/

@interface NSSound (VLCAdditions)
+ (float)systemVolumeForChannel:(int)channel;
+ (bool)setSystemVolume:(float)volume forChannel:(int)channel;
+ (void)increaseSystemVolume;
+ (void)decreaseSystemVolume;
@end

/*****************************************************************************
 * NSAnimation (VLCAddition)
 *****************************************************************************/

@interface NSAnimation (VLCAdditions)
@property (readwrite) void * userInfo;

@end

/*****************************************************************************
 * NSScreen (VLCAdditions)
 *
 *  Missing extension to NSScreen
 *****************************************************************************/

@interface NSScreen (VLCAdditions)

+ (NSScreen *)screenWithDisplayID: (CGDirectDisplayID)displayID;
- (BOOL)hasMenuBar;
- (BOOL)hasDock;
- (BOOL)isScreen: (NSScreen*)screen;
- (CGDirectDisplayID)displayID;
- (void)blackoutOtherScreens;
+ (void)unblackoutScreens;

- (void)setFullscreenPresentationOptions;
- (void)setNonFullscreenPresentationOptions;
@end

/*****************************************************************************
 * VLCDragDropView
 *
 * Disables default drag / drop behaviour of an NSImageView.
 * set it for all sub image views withing an VLCDragDropView.
 *****************************************************************************/


@interface VLCDropDisabledImageView : NSImageView

@end

/*****************************************************************************
 * VLCDragDropView
 *****************************************************************************/

@interface VLCDragDropView : NSView

@property (nonatomic, assign) id dropHandler;
@property (nonatomic, assign) BOOL drawBorder;

- (void)enablePlaylistItems;

@end


/*****************************************************************************
 * MPSlider
 *****************************************************************************/

@interface MPSlider : NSSlider

@end

/*****************************************************************************
 * ProgressView
 *****************************************************************************/

@interface VLCProgressView : NSView

- (void)scrollWheel:(NSEvent *)o_event;

@end


/*****************************************************************************
 * TimeLineSlider
 *****************************************************************************/

@interface TimeLineSlider : NSSlider

@property (readonly) CGFloat knobPosition;

- (void)drawRect:(NSRect)rect;
- (void)drawKnobInRect:(NSRect)knobRect;

@end

/*****************************************************************************
 * VLCVolumeSliderCommon
 *****************************************************************************/

@interface VLCVolumeSliderCommon : NSSlider

@property (readwrite, nonatomic) BOOL usesBrightArtwork;

- (void)scrollWheel:(NSEvent *)o_event;
- (void)drawFullVolumeMarker;

- (CGFloat)fullVolumePos;

@end

@interface VolumeSliderCell : NSSliderCell
@end

/*****************************************************************************
 * ITSlider
 *****************************************************************************/

@interface ITSlider : VLCVolumeSliderCommon

@end

/*****************************************************************************
 * VLCTimeField interface
 *****************************************************************************
 * we need the implementation to catch our click-event in the controller window
 *****************************************************************************/

@interface VLCTimeField : NSTextField

@property (readonly) BOOL timeRemaining;

- (void)setRemainingIdentifier:(NSString *)o_string;

@end

/*****************************************************************************
 * VLCMainWindowSplitView interface
 *****************************************************************************/
@interface VLCMainWindowSplitView : NSSplitView

@end

/*****************************************************************************
 * VLCThreePartImageView interface
 *****************************************************************************/
@interface VLCThreePartImageView : NSView

- (void)setImagesLeft:(NSImage *)left middle: (NSImage *)middle right:(NSImage *)right;

@end


/*****************************************************************************
 * PositionFormatter interface
 *
 * Formats a text field to only accept decimals and :
 *****************************************************************************/
@interface PositionFormatter : NSFormatter

- (NSString*)stringForObjectValue:(id)obj;

- (BOOL)getObjectValue:(id*)obj
             forString:(NSString*)string
      errorDescription:(NSString**)error;

- (BOOL)isPartialStringValid:(NSString*)partialString
            newEditingString:(NSString**)newString
            errorDescription:(NSString**)error;

@end

/*****************************************************************************
 * NSView addition
 *****************************************************************************/

@interface NSView (EnableSubviews)
- (void)enableSubviews:(BOOL)b_enable;
@end

/*****************************************************************************
 * VLCByteCountFormatter addition
 *****************************************************************************/

#ifndef MAC_OS_X_VERSION_10_8
enum {
    // Specifies display of file or storage byte counts. The actual behavior for this is platform-specific; on OS X 10.7 and less, this uses the binary style, but decimal style on 10.8 and above
    NSByteCountFormatterCountStyleFile   = 0,
    // Specifies display of memory byte counts. The actual behavior for this is platform-specific; on OS X 10.7 and less, this uses the binary style, but that may change over time.
    NSByteCountFormatterCountStyleMemory = 1,
    // The following two allow specifying the number of bytes for KB explicitly. It's better to use one of the above values in most cases.
    NSByteCountFormatterCountStyleDecimal = 2,    // 1000 bytes are shown as 1 KB
    NSByteCountFormatterCountStyleBinary  = 3     // 1024 bytes are shown as 1 KB
};
typedef NSInteger NSByteCountFormatterCountStyle;
#endif

@interface VLCByteCountFormatter : NSFormatter {
}

+ (NSString *)stringFromByteCount:(long long)byteCount countStyle:(NSByteCountFormatterCountStyle)countStyle;
@end

extern NSString *const VLCOpenTextFieldWasClicked;

@interface VLCOpenTextField : NSTextField
- (void)mouseDown:(NSEvent *)theEvent;
@end
