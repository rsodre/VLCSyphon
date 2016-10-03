/*****************************************************************************
 * helpers.h
 *****************************************************************************
 * Copyright (C) 2009-2015 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Pierre d'Herbemont <pdherbemont # videolan org>
 *          Felix Paul Kühne <fkuehne at videolan dot org>
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

#import "intf.h"
#import "VideoView.h"

static inline input_thread_t *getInput(void)
{
    intf_thread_t *p_intf = getIntf();
    if (!p_intf)
        return NULL;
    return pl_CurrentInput(p_intf);
}

static inline vout_thread_t *getVout(void)
{
    input_thread_t *p_input = getInput();
    if (!p_input)
        return NULL;
    vout_thread_t *p_vout = input_GetVout(p_input);
    vlc_object_release(p_input);
    return p_vout;
}

static inline vout_thread_t *getVoutForActiveWindow(void)
{
    vout_thread_t *p_vout = nil;

    id currentWindow = [NSApp keyWindow];
    if ([currentWindow respondsToSelector:@selector(videoView)]) {
        VLCVoutView *videoView = [currentWindow videoView];
        if (videoView) {
            p_vout = [videoView voutThread];
        }
    }

    if (!p_vout)
        p_vout = getVout();

    return p_vout;
}

static inline audio_output_t *getAout(void)
{
    intf_thread_t *p_intf = getIntf();
    if (!p_intf)
        return NULL;
    return playlist_GetAout(pl_Get(p_intf));
}
