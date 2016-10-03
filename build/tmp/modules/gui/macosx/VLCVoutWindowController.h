/*****************************************************************************
 * VLCVoutWindowController.h: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2012-2014 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne -at- videolan -dot- org>
 *          David Fuhrmann <david dot fuhrmann at googlemail dot com>
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

#import <vlc_vout_window.h>
#import "KeyboardBacklight.h"

@class VLCControlsBarCommon;
@class VLCVideoWindowCommon;
@class VLCVoutView;

@interface VLCVoutWindowController : NSObject

@property (readonly, atomic) NSLock *lock;

@property (readonly, nonatomic) NSInteger currentStatusWindowLevel;

- (VLCVoutView *)setupVoutForWindow:(vout_window_t *)p_wnd withProposedVideoViewPosition:(NSRect)videoViewPosition;
- (void)removeVoutforDisplay:(NSValue *)o_key;
- (void)setNativeVideoSize:(NSSize)size forWindow:(vout_window_t *)p_wnd;
- (void)setWindowLevel:(NSInteger)i_level forWindow:(vout_window_t *)p_wnd;
- (void)setFullscreen:(int)i_full forWindow:(vout_window_t *)p_wnd withAnimation:(BOOL)b_animation;

- (void)updateControlsBarsUsingBlock:(void (^)(VLCControlsBarCommon *controlsBar))block;
- (void)updateWindowsUsingBlock:(void (^)(VLCVideoWindowCommon *o_window))windowUpdater;

- (void)updateWindowLevelForHelperWindows:(NSInteger)i_level;

@end
