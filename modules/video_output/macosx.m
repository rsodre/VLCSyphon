/*****************************************************************************
 * macosx.m: MacOS X OpenGL provider
 *****************************************************************************
 * Copyright (C) 2001-2013 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Derk-Jan Hartman <hartman at videolan dot org>
 *          Eric Petit <titer@m0k.org>
 *          Benjamin Pracht <bigben at videolan dot org>
 *          Damien Fouilleul <damienf at videolan dot org>
 *          Pierre d'Herbemont <pdherbemont at videolan dot org>
 *          Felix Paul Kühne <fkuehne at videolan dot org>
 *          David Fuhrmann <david dot fuhrmann at googlemail dot com>
 *          Rémi Denis-Courmont
 *          Juho Vähä-Herttua <juhovh at iki dot fi>
 *          Laurent Aimar <fenrir _AT_ videolan _DOT_ org>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

/*****************************************************************************
 * Preamble
 *****************************************************************************/

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <dlfcn.h>

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <vlc_common.h>
#include <vlc_plugin.h>
#include <vlc_vout_display.h>
#include <vlc_opengl.h>
#include <vlc_dialog.h>
#include "opengl.h"

#define OSX_EL_CAPITAN (NSAppKitVersionNumber >= 1404)

// ROGER  -- SYPHON
#include "syphonServer.h"

/**
 * Forward declarations
 */
static int Open (vlc_object_t *);
static void Close (vlc_object_t *);

static picture_pool_t *Pool (vout_display_t *vd, unsigned requested_count);
static void PictureRender (vout_display_t *vd, picture_t *pic, subpicture_t *subpicture);
static void PictureDisplay (vout_display_t *vd, picture_t *pic, subpicture_t *subpicture);
static int Control (vout_display_t *vd, int query, va_list ap);

static void *OurGetProcAddress(vlc_gl_t *, const char *);

static int OpenglLock (vlc_gl_t *gl);
static void OpenglUnlock (vlc_gl_t *gl);
static void OpenglSwap (vlc_gl_t *gl);

/**
 * Module declaration
 */
vlc_module_begin ()
    /* Will be loaded even without interface module. see voutgl.m */
    set_shortname ("Mac OS X")
    set_description (N_("Mac OS X OpenGL video output (Syphon)"))
    set_category (CAT_VIDEO)
    set_subcategory (SUBCAT_VIDEO_VOUT)
    set_capability ("vout display", 300)
    set_callbacks (Open, Close)

    add_shortcut ("macosx", "vout_macosx")
vlc_module_end ()

/**
 * Obj-C protocol declaration that drawable-nsobject should follow
 */
@protocol VLCOpenGLVideoViewEmbedding <NSObject>
- (void)addVoutSubview:(NSView *)view;
- (void)removeVoutSubview:(NSView *)view;
@end

@interface VLCOpenGLVideoView : NSOpenGLView
{
    vout_display_t *vd;
    BOOL _hasPendingReshape;
}
- (void)setVoutDisplay:(vout_display_t *)vd;
- (void)setVoutFlushing:(BOOL)flushing;
@end


struct vout_display_sys_t
{
    VLCOpenGLVideoView *glView;
    id<VLCOpenGLVideoViewEmbedding> container;

    CGColorSpaceRef cgColorSpace;
    NSColorSpace *nsColorSpace;

    vout_window_t *embed;
    vlc_gl_t gl;
    vout_display_opengl_t *vgl;

    picture_pool_t *pool;
    picture_t *current;
    bool has_first_frame;

    vout_display_place_t place;
};


static void *OurGetProcAddress(vlc_gl_t *gl, const char *name)
{
    VLC_UNUSED(gl);

    return dlsym(RTLD_DEFAULT, name);
}

static int Open (vlc_object_t *this)
{
    vout_display_t *vd = (vout_display_t *)this;
    vout_display_sys_t *sys = calloc (1, sizeof(*sys));

    if (!sys)
        return VLC_ENOMEM;

    @autoreleasepool {
        if (!CGDisplayUsesOpenGLAcceleration (kCGDirectMainDisplay))
            msg_Err (this, "no OpenGL hardware acceleration found. this can lead to slow output and unexpected results");

        vd->sys = sys;
        sys->pool = NULL;
        sys->gl.sys = NULL;
        sys->embed = NULL;

        /* Get the drawable object */
        id container = var_CreateGetAddress (vd, "drawable-nsobject");
        if (container)
            vout_display_DeleteWindow (vd, NULL);
        else {
            sys->embed = vout_display_NewWindow (vd, VOUT_WINDOW_TYPE_NSOBJECT);
            if (sys->embed)
                container = sys->embed->handle.nsobject;

            if (!container) {
                msg_Err(vd, "No drawable-nsobject nor vout_window_t found, passing over.");
                goto error;
            }
        }

        /* This will be released in Close(), on
         * main thread, after we are done using it. */
        sys->container = [container retain];

        /* support for BT.709 and BT.2020 color spaces was introduced with OS X 10.11
         * on older OS versions, we can't show correct colors, so we fallback on linear RGB */
        if (OSX_EL_CAPITAN) {
            switch (vd->fmt.primaries) {
                case COLOR_PRIMARIES_BT601_525:
                case COLOR_PRIMARIES_BT601_625:
                {
                    msg_Dbg(vd, "Using BT.601 color space");
                    sys->cgColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
                    break;
                }
                case COLOR_PRIMARIES_BT709:
                {
                    msg_Dbg(vd, "Using BT.709 color space");
                    sys->cgColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
                    break;
                }
                case COLOR_PRIMARIES_BT2020:
                {
                    msg_Dbg(vd, "Using BT.2020 color space");
                    sys->cgColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
                    break;
                }
                case COLOR_PRIMARIES_DCI_P3:
                {
                    msg_Dbg(vd, "Using DCI P3 color space");
                    sys->cgColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceDCIP3);
                    break;
                }
                default:
                {
                    msg_Dbg(vd, "Guessing color space based on video dimensions (%ix%i)", vd->fmt.i_visible_width, vd->fmt.i_visible_height);
                    if (vd->fmt.i_visible_height >= 2000 || vd->fmt.i_visible_width >= 3800) {
                        msg_Dbg(vd, "Using BT.2020 color space");
                        sys->cgColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2020);
                    } else if (vd->fmt.i_height > 576) {
                        msg_Dbg(vd, "Using BT.709 color space");
                        sys->cgColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
                    } else {
                        msg_Dbg(vd, "SD content, using linear RGB color space");
                        sys->cgColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
                    }
                    break;
                }
            }
        } else {
            msg_Dbg(vd, "OS does not support BT.709 or BT.2020 color spaces, output may vary");
            sys->cgColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        }
        sys->nsColorSpace = [[NSColorSpace alloc] initWithCGColorSpace:sys->cgColorSpace];

        /* Get our main view*/
        [VLCOpenGLVideoView performSelectorOnMainThread:@selector(getNewView:)
                                             withObject:[NSValue valueWithPointer:&sys->glView]
                                          waitUntilDone:YES];
        if (!sys->glView) {
            msg_Err(vd, "Initialization of open gl view failed");
            goto error;
        }

        [sys->glView setVoutDisplay:vd];

        /* We don't wait, that means that we'll have to be careful about releasing
         * container.
         * That's why we'll release on main thread in Close(). */
        if ([(id)container respondsToSelector:@selector(addVoutSubview:)])
            [(id)container performSelectorOnMainThread:@selector(addVoutSubview:)
                                            withObject:sys->glView
                                         waitUntilDone:NO];
        else if ([container isKindOfClass:[NSView class]]) {
            NSView *parentView = container;
            [parentView performSelectorOnMainThread:@selector(addSubview:)
                                         withObject:sys->glView
                                      waitUntilDone:NO];
            [sys->glView performSelectorOnMainThread:@selector(setFrameToBoundsOfView:)
                                          withObject:[NSValue valueWithPointer:parentView]
                                       waitUntilDone:NO];
        } else {
            msg_Err(vd, "Invalid drawable-nsobject object. drawable-nsobject must either be an NSView or comply to the @protocol VLCOpenGLVideoViewEmbedding.");
            goto error;
        }

        /* Initialize common OpenGL video display */
        sys->gl.lock = OpenglLock;
        sys->gl.unlock = OpenglUnlock;
        sys->gl.swap = OpenglSwap;
        sys->gl.getProcAddress = OurGetProcAddress;
        sys->gl.sys = sys;
        const vlc_fourcc_t *subpicture_chromas;

        sys->vgl = vout_display_opengl_New (&vd->fmt, &subpicture_chromas, &sys->gl);
        if (!sys->vgl) {
            msg_Err(vd, "Error while initializing opengl display.");
            sys->gl.sys = NULL;
            goto error;
        }

        /* */
        vout_display_info_t info = vd->info;
        info.has_pictures_invalid = false;
        info.has_event_thread = true;
        info.subpicture_chromas = subpicture_chromas;
        info.has_hide_mouse = true;

        /* Setup vout_display_t once everything is fine */
        vd->info = info;
        
        vd->pool = Pool;
        vd->prepare = PictureRender;
        vd->display = PictureDisplay;
        vd->control = Control;
        
        /* */
        vout_display_SendEventDisplaySize (vd, vd->fmt.i_visible_width, vd->fmt.i_visible_height);
		
		// ROGER -- SYPHON
		//syphon_log_to_file();
		syphon_open(nil);
		SyphonLog(@"Open!");
		
        return VLC_SUCCESS;
        
    error:
        Close(this);
        return VLC_EGENERIC;
    }
}

void Close (vlc_object_t *this)
{
    vout_display_t *vd = (vout_display_t *)this;
    vout_display_sys_t *sys = vd->sys;

    @autoreleasepool {
        [sys->glView setVoutDisplay:nil];

        var_Destroy (vd, "drawable-nsobject");
        if ([(id)sys->container respondsToSelector:@selector(removeVoutSubview:)])
        /* This will retain sys->glView */
            [(id)sys->container performSelectorOnMainThread:@selector(removeVoutSubview:)
                                                 withObject:sys->glView
                                              waitUntilDone:NO];

        /* release on main thread as explained in Open() */
        [(id)sys->container performSelectorOnMainThread:@selector(release)
                                             withObject:nil
                                          waitUntilDone:NO];
        [sys->glView performSelectorOnMainThread:@selector(removeFromSuperview)
                                      withObject:nil
                                   waitUntilDone:NO];

        if (sys->gl.sys != NULL)
            vout_display_opengl_Delete (sys->vgl);

        [sys->glView release];

        if (sys->cgColorSpace != nil)
            CGColorSpaceRelease(sys->cgColorSpace);

        if (sys->nsColorSpace != nil)
            [sys->nsColorSpace release];

        if (sys->embed)
            vout_display_DeleteWindow (vd, sys->embed);
        free (sys);
		
		// ROGER -- SYPHON
		syphon_close(false);
		SyphonLog(@"Closed!");
    }
}

/*****************************************************************************
 * vout display callbacks
 *****************************************************************************/

static picture_pool_t *Pool (vout_display_t *vd, unsigned requested_count)
{
    vout_display_sys_t *sys = vd->sys;

    if (!sys->pool)
        sys->pool = vout_display_opengl_GetPool (sys->vgl, requested_count);
    assert(sys->pool);
    return sys->pool;
}

static void PictureRender (vout_display_t *vd, picture_t *pic, subpicture_t *subpicture)
{

    vout_display_sys_t *sys = vd->sys;

    vout_display_opengl_Prepare (sys->vgl, pic, subpicture);
}

static void PictureDisplay (vout_display_t *vd, picture_t *pic, subpicture_t *subpicture)
{
    vout_display_sys_t *sys = vd->sys;
    [sys->glView setVoutFlushing:YES];
	vout_display_opengl_Display (sys->vgl, &vd->source);
	[sys->glView setVoutFlushing:NO];

	// ROGER -- SYPHON
	syphon_display_opengl_Display(sys->vgl, &vd->source);
	
	picture_Release (pic);
    sys->has_first_frame = true;

    if (subpicture)
        subpicture_Delete(subpicture);
}

static int Control (vout_display_t *vd, int query, va_list ap)
{
    vout_display_sys_t *sys = vd->sys;

    if (!vd->sys)
        return VLC_EGENERIC;

    if (!sys->embed)
        return VLC_EGENERIC;

    @autoreleasepool {
        switch (query)
        {
            case VOUT_DISPLAY_CHANGE_DISPLAY_FILLED:
            case VOUT_DISPLAY_CHANGE_ZOOM:
            case VOUT_DISPLAY_CHANGE_SOURCE_ASPECT:
            case VOUT_DISPLAY_CHANGE_SOURCE_CROP:
            case VOUT_DISPLAY_CHANGE_DISPLAY_SIZE:
            {

                id o_window = [sys->glView window];
                if (!o_window) {
                    return VLC_SUCCESS; // this is okay, since the event will occur again when we have a window
                }

                NSSize windowMinSize = [o_window minSize];

                const vout_display_cfg_t *cfg;
                const video_format_t *source;

                if (query == VOUT_DISPLAY_CHANGE_SOURCE_ASPECT || query == VOUT_DISPLAY_CHANGE_SOURCE_CROP) {
                    source = (const video_format_t *)va_arg (ap, const video_format_t *);
                    cfg = vd->cfg;
                } else {
                    source = &vd->source;
                    cfg = (const vout_display_cfg_t*)va_arg (ap, const vout_display_cfg_t *);
                }

                /* we always use our current frame here, because we have some size constraints
                 in the ui vout provider */
                vout_display_cfg_t cfg_tmp = *cfg;
                /* on HiDPI displays, the point bounds don't equal the actual pixel based bounds */
                NSRect bounds = [sys->glView convertRectToBacking:[sys->glView bounds]];
                cfg_tmp.display.width = bounds.size.width;
                cfg_tmp.display.height = bounds.size.height;

                vout_display_place_t place;
                vout_display_PlacePicture (&place, source, &cfg_tmp, false);
                @synchronized (sys->glView) {
                    sys->place = place;
                }

                /* For resize, we call glViewport in reshape and not here.
                 This has the positive side effect that we avoid erratic sizing as we animate every resize. */
                if (query != VOUT_DISPLAY_CHANGE_DISPLAY_SIZE)
                    // x / y are top left corner, but we need the lower left one
                    glViewport (place.x, cfg_tmp.display.height - (place.y + place.height), place.width, place.height);

                return VLC_SUCCESS;
            }

            case VOUT_DISPLAY_HIDE_MOUSE:
            {
                [NSCursor setHiddenUntilMouseMoves: YES];
                return VLC_SUCCESS;
            }
                
            case VOUT_DISPLAY_RESET_PICTURES:
                vlc_assert_unreachable ();
            default:
                msg_Err (vd, "Unknown request in Mac OS X vout display");
                return VLC_EGENERIC;
        }
    }
}

/*****************************************************************************
 * vout opengl callbacks
 *****************************************************************************/
static int OpenglLock (vlc_gl_t *gl)
{
    vout_display_sys_t *sys = (vout_display_sys_t *)gl->sys;
    if (!sys->glView || ![sys->glView respondsToSelector:@selector(openGLContext)])
        return 1;

    NSOpenGLContext *context = [sys->glView openGLContext];
    CGLError err = CGLLockContext ([context CGLContextObj]);
    if (kCGLNoError == err) {
        [context makeCurrentContext];
        return 0;
    }
    return 1;
}

static void OpenglUnlock (vlc_gl_t *gl)
{
    vout_display_sys_t *sys = (vout_display_sys_t *)gl->sys;
    CGLUnlockContext ([[sys->glView openGLContext] CGLContextObj]);
}

static void OpenglSwap (vlc_gl_t *gl)
{
    vout_display_sys_t *sys = (vout_display_sys_t *)gl->sys;
    [[sys->glView openGLContext] flushBuffer];
}

/*****************************************************************************
 * Our NSView object
 *****************************************************************************/
@implementation VLCOpenGLVideoView

#define VLCAssertMainThread() assert([[NSThread currentThread] isMainThread])


+ (void)getNewView:(NSValue *)value
{
    id *ret = [value pointerValue];
    *ret = [[self alloc] init];
}

/**
 * Gets called by the Open() method.
 */
- (id)init
{
    VLCAssertMainThread();

    /* Warning - this may be called on non main thread */

    NSOpenGLPixelFormatAttribute attribs[] =
    {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAWindow,
        NSOpenGLPFAAllowOfflineRenderers,
        0
    };

    NSOpenGLPixelFormat *fmt = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];

    if (!fmt)
        return nil;

    self = [super initWithFrame:NSMakeRect(0,0,10,10) pixelFormat:fmt];
    [fmt release];

    if (!self)
        return nil;

    /* enable HiDPI support */
    [self setWantsBestResolutionOpenGLSurface:YES];

    /* request our screen's HDR mode (introduced in OS X 10.11) */
    if ([self respondsToSelector:@selector(setWantsExtendedDynamicRangeOpenGLSurface:)]) {
        [self setWantsExtendedDynamicRangeOpenGLSurface:YES];
    }

    /* Swap buffers only during the vertical retrace of the monitor.
     http://developer.apple.com/documentation/GraphicsImaging/
     Conceptual/OpenGL/chap5/chapter_5_section_44.html */
    GLint params[] = { 1 };
    CGLSetParameter ([[self openGLContext] CGLContextObj], kCGLCPSwapInterval, params);

    [[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationDidChangeScreenParametersNotification
                                                      object:[NSApplication sharedApplication]
                                                       queue:nil
                                                  usingBlock:^(NSNotification *notification) {
                                                      [self performSelectorOnMainThread:@selector(reshape)
                                                                             withObject:nil
                                                                          waitUntilDone:NO];
                                                  }];

    [self setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

/**
 * Gets called by the Open() method.
 */
- (void)setFrameToBoundsOfView:(NSValue *)value
{
    NSView *parentView = [value pointerValue];
    [self setFrame:[parentView bounds]];
}

/**
 * Gets called by the Close and Open methods.
 * (Non main thread).
 */
- (void)setVoutDisplay:(vout_display_t *)aVd
{
    @synchronized(self) {
        vd = aVd;
    }
}

/**
 * Gets called when the vout will aquire the lock and flush.
 * (Non main thread).
 */
- (void)setVoutFlushing:(BOOL)flushing
{
    if (!flushing)
        return;
    @synchronized(self) {
        _hasPendingReshape = NO;
    }
}

/**
 * Can -drawRect skip rendering?.
 */
- (BOOL)canSkipRendering
{
    VLCAssertMainThread();

    @synchronized(self) {
        BOOL hasFirstFrame = vd && vd->sys->has_first_frame;
        return !_hasPendingReshape && hasFirstFrame;
    }
}


/**
 * Local method that locks the gl context.
 */
- (BOOL)lockgl
{
    VLCAssertMainThread();
    NSOpenGLContext *context = [self openGLContext];
    CGLError err = CGLLockContext ([context CGLContextObj]);
    if (err == kCGLNoError)
        [context makeCurrentContext];
    return err == kCGLNoError;
}

/**
 * Local method that unlocks the gl context.
 */
- (void)unlockgl
{
    VLCAssertMainThread();
    CGLUnlockContext ([[self openGLContext] CGLContextObj]);
}

/**
 * Local method that force a rendering of a frame.
 * This will get called if Cocoa forces us to redraw (via -drawRect).
 */
- (void)render
{
    VLCAssertMainThread();

    // We may have taken some times to take the opengl Lock.
    // Check here to see if we can just skip the frame as well.
    if ([self canSkipRendering])
        return;

    BOOL hasFirstFrame;
    @synchronized(self) { // vd can be accessed from multiple threads
        hasFirstFrame = vd && vd->sys->has_first_frame;
    }

    if (hasFirstFrame)
        // This will lock gl.
        vout_display_opengl_Display (vd->sys->vgl, &vd->source);
    else
        glClear (GL_COLOR_BUFFER_BIT);
}

/**
 * Method called by Cocoa when the view is resized.
 */
- (void)reshape
{
    VLCAssertMainThread();

    /* on HiDPI displays, the point bounds don't equal the actual pixel based bounds */
    NSRect bounds = [self convertRectToBacking:[self bounds]];
    vout_display_place_t place;

    @synchronized(self) {
        if (vd) {
            vout_display_cfg_t cfg_tmp = *(vd->cfg);
            cfg_tmp.display.width  = bounds.size.width;
            cfg_tmp.display.height = bounds.size.height;

            vout_display_PlacePicture (&place, &vd->source, &cfg_tmp, false);
            vd->sys->place = place;
            vout_display_SendEventDisplaySize (vd, bounds.size.width, bounds.size.height);
        }
    }

    if ([self lockgl]) {
        // x / y are top left corner, but we need the lower left one
        glViewport (place.x, bounds.size.height - (place.y + place.height), place.width, place.height);

        @synchronized(self) {
            // This may be cleared before -drawRect is being called,
            // in this case we'll skip the rendering.
            // This will save us for rendering two frames (or more) for nothing
            // (one by the vout, one (or more) by drawRect)
            _hasPendingReshape = YES;
        }

        [self unlockgl];

        [super reshape];
    }
}

/**
 * Method called by Cocoa when the view is resized or the location has changed.
 * We just need to make sure we are locking here.
 */
- (void)update
{
    VLCAssertMainThread();
    BOOL success = [self lockgl];
    if (!success)
        return;

    [super update];

    [self unlockgl];
}

/**
 * Method called by Cocoa to force redraw.
 */
- (void)drawRect:(NSRect) rect
{
    VLCAssertMainThread();

    if ([self canSkipRendering])
        return;

    BOOL success = [self lockgl];
    if (!success)
        return;

    [self render];

    [self unlockgl];
}

- (void)renewGState
{
    NSWindow *window = [self window];

    // Remove flashes with splitter view.
    if ([window respondsToSelector:@selector(disableScreenUpdatesUntilFlush)])
        [window disableScreenUpdatesUntilFlush];

    [super renewGState];
}

- (BOOL)isOpaque
{
    return YES;
}

#pragma mark -
#pragma mark Mouse handling

- (void)mouseDown:(NSEvent *)o_event
{
    @synchronized (self) {
        if (vd) {
            if ([o_event type] == NSLeftMouseDown && !([o_event modifierFlags] &  NSControlKeyMask)) {
                if ([o_event clickCount] <= 1)
                    vout_display_SendEventMousePressed (vd, MOUSE_BUTTON_LEFT);
            }
        }
    }

    [super mouseDown:o_event];
}

- (void)otherMouseDown:(NSEvent *)o_event
{
    @synchronized (self) {
        if (vd)
            vout_display_SendEventMousePressed (vd, MOUSE_BUTTON_CENTER);
    }

    [super otherMouseDown: o_event];
}

- (void)mouseUp:(NSEvent *)o_event
{
    @synchronized (self) {
        if (vd) {
            if ([o_event type] == NSLeftMouseUp)
                vout_display_SendEventMouseReleased (vd, MOUSE_BUTTON_LEFT);
        }
    }

    [super mouseUp: o_event];
}

- (void)otherMouseUp:(NSEvent *)o_event
{
    @synchronized (self) {
        if (vd)
            vout_display_SendEventMouseReleased (vd, MOUSE_BUTTON_CENTER);
    }

    [super otherMouseUp: o_event];
}

- (void)mouseMoved:(NSEvent *)o_event
{
    /* on HiDPI displays, the point bounds don't equal the actual pixel based bounds */
    NSPoint ml = [self convertPoint: [o_event locationInWindow] fromView: nil];
    NSRect videoRect = [self bounds];
    BOOL b_inside = [self mouse: ml inRect: videoRect];

    ml = [self convertPointToBacking: ml];
    videoRect = [self convertRectToBacking: videoRect];

    if (b_inside) {
        @synchronized (self) {
            if (vd) {
                vout_display_SendMouseMovedDisplayCoordinates(vd, ORIENT_NORMAL,
                                                              (int)ml.x, videoRect.size.height - (int)ml.y,
                                                              &vd->sys->place);
            }
        }
    }

    [super mouseMoved: o_event];
}

- (void)mouseDragged:(NSEvent *)o_event
{
    [self mouseMoved: o_event];
    [super mouseDragged: o_event];
}

- (void)otherMouseDragged:(NSEvent *)o_event
{
    [self mouseMoved: o_event];
    [super otherMouseDragged: o_event];
}

- (void)rightMouseDragged:(NSEvent *)o_event
{
    [self mouseMoved: o_event];
    [super rightMouseDragged: o_event];
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (BOOL)mouseDownCanMoveWindow
{
    return YES;
}

- (void)viewWillMoveToWindow:(nullable NSWindow *)newWindow
{
    [super viewWillMoveToWindow:newWindow];

    if (newWindow != nil) {
        @synchronized(newWindow) {
            [newWindow setColorSpace:vd->sys->nsColorSpace];
        }
    }
}

@end
