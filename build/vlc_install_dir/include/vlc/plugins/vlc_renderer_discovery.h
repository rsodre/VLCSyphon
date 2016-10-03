/*****************************************************************************
 * vlc_renderer_discovery.h : Renderer Discovery functions
 *****************************************************************************
 * Copyright (C) 2016 VLC authors and VideoLAN
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

#ifndef VLC_RENDERER_DISCOVERY_H
#define VLC_RENDERER_DISCOVERY_H 1

#include <vlc_input.h>
#include <vlc_events.h>
#include <vlc_probe.h>
#include <vlc_url.h>

/**
 * @defgroup vlc_renderer VLC renderer discovery
 * @{
 *
 * @file
 * This file declares VLC renderer discvoery structures and functions
 *
 * @defgroup vlc_renderer_item VLC renderer items returned by the discovery
 * @{
 */

typedef struct vlc_renderer_item vlc_renderer_item;

#define VLC_RENDERER_CAN_AUDIO 0x0001
#define VLC_RENDERER_CAN_VIDEO 0x0002

/**
 * Create a new renderer item
 *
 * @param psz_name name of the item
 * @param psz_uri uri of the renderer item, must contains a valid protocol and
 * a valid host
 * @param psz_extra_sout extra sout options
 * @param psz_icon_uri icon uri of the renderer item
 * @param i_flags flags for the item
 * @return a renderer item or NULL in case of error
 */
VLC_API vlc_renderer_item *
vlc_renderer_item_new(const char *psz_name, const char *psz_uri,
                      const char *psz_extra_sout, const char *psz_icon_uri,
                      int i_flags) VLC_USED;

/**
 * Hold a renderer item, i.e. creates a new reference
 */
VLC_API vlc_renderer_item *
vlc_renderer_item_hold(vlc_renderer_item *p_item);

/**
 * Releases a renderer item, i.e. decrements its reference counter
 */
VLC_API void
vlc_renderer_item_release(vlc_renderer_item *p_item);

/**
 * Get the human readable name of a renderer item
 */
VLC_API const char *
vlc_renderer_item_name(const vlc_renderer_item *p_item);

/**
 * Get the sout command of a renderer item
 */
VLC_API const char *
vlc_renderer_item_sout(const vlc_renderer_item *p_item);

/**
 * Get the icon uri of a renderer item
 */
VLC_API const char *
vlc_renderer_item_icon_uri(const vlc_renderer_item *p_item);

/**
 * Get the flags of a renderer item
 */
VLC_API int
vlc_renderer_item_flags(const vlc_renderer_item *p_item);

/**
 * Set an opaque context
 */
VLC_API void
vlc_renderer_item_set_ctx(vlc_renderer_item *p_item, void *p_ctx);

/**
 * Get the opaque context previously set
 */
VLC_API void*
vlc_renderer_item_ctx(const vlc_renderer_item *p_item);

/**
 * @}
 * @defgroup vlc_renderer_discovery VLC renderer discovery interface
 * @{
 */

typedef struct vlc_renderer_discovery vlc_renderer_discovery;
typedef struct vlc_renderer_discovery_sys vlc_renderer_discovery_sys;

/**
 * Return a list of renderer discovery modules
 *
 * @param pppsz_names a pointer to a list of module name, NULL terminated
 * @param pppsz_longnames a pointer to a list of module longname, NULL
 * terminated
 *
 * @return VLC_SUCCESS on success, or VLC_EGENERIC on error
 */
VLC_API int
vlc_rd_get_names(vlc_object_t *p_obj, char ***pppsz_names,
                 char ***pppsz_longnames) VLC_USED;
#define vlc_rd_get_names(a, b, c) \
        vlc_rd_get_names(VLC_OBJECT(a), b, c)

/**
 * Create a new renderer discovery module
 *
 * @param psz_name name of the module to load, see vlc_rd_get_names() to get
 * the list of names
 *
 * @return a valid vlc_renderer_discovery, need to be released with
 * vlc_rd_release()
 */
VLC_API vlc_renderer_discovery *
vlc_rd_new(vlc_object_t *p_obj, const char *psz_name) VLC_USED;

#define vlc_rd_release(p_rd) vlc_object_release(p_rd)

/**
 * Get the event manager of the renderer discovery module
 *
 * @see vlc_RendererDiscoveryItemAdded
 * @see vlc_RendererDiscoveryItemRemoved
 */
VLC_API vlc_event_manager_t *
vlc_rd_event_manager(vlc_renderer_discovery *p_rd);

/**
 * Start the renderer discovery module
 *
 * Once started, the module can send new vlc_renderer_item via the
 * vlc_RendererDiscoveryItemAdded event.
 */
VLC_API int
vlc_rd_start(vlc_renderer_discovery *p_rd);

/**
 * Stop the renderer discovery module
 */
VLC_API void
vlc_rd_stop(vlc_renderer_discovery *p_rd);

/**
 * @}
 * @defgroup vlc_renderer_discovery_module VLC renderer module
 * @{
 */

struct vlc_renderer_discovery
{
    VLC_COMMON_MEMBERS
    module_t *          p_module;

    vlc_event_manager_t event_manager;

    char *              psz_name;
    config_chain_t *    p_cfg;

    vlc_renderer_discovery_sys *p_sys;
};

/**
 * Add a new renderer item
 *
 * This will send the vlc_RendererDiscoveryItemAdded event
 */
VLC_API void
vlc_rd_add_item(vlc_renderer_discovery * p_rd, vlc_renderer_item * p_item);

/**
 * Add a new renderer item
 *
 * This will send the vlc_RendererDiscoveryItemRemoved event
 */
VLC_API void
vlc_rd_remove_item(vlc_renderer_discovery * p_rd, vlc_renderer_item * p_item);

/**
 * Renderer Discovery proble helpers
 */
VLC_API int
vlc_rd_probe_add(vlc_probe_t *p_probe, const char *psz_name,
                 const char *psz_longname);

#define VLC_RD_PROBE_HELPER(name, longname) \
static int vlc_rd_probe_open(vlc_object_t *obj) \
{ \
    return vlc_rd_probe_add((struct vlc_probe_t *)obj, name, longname); \
}

#define VLC_RD_PROBE_SUBMODULE \
    add_submodule() \
        set_capability("renderer probe", 100) \
        set_callbacks(vlc_rd_probe_open, NULL)

/** @} @} */

#endif
