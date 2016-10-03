/*****************************************************************************
 * vlc_filter.h: filter related structures and functions
 *****************************************************************************
 * Copyright (C) 1999-2014 VLC authors and VideoLAN
 *
 * Authors: Gildas Bazin <gbazin@videolan.org>
 *          Antoine Cellerier <dionoea at videolan dot org>
 *          Rémi Denis-Courmont
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

#ifndef VLC_FILTER_H
#define VLC_FILTER_H 1

#include <vlc_es.h>
#include <vlc_picture.h>
#include <vlc_subpicture.h>
#include <vlc_mouse.h>

/**
 * \defgroup filter Filters
 * \ingroup output
 * Audio, video, text filters
 * @{
 * \file
 * Filter modules interface
 */

typedef struct filter_owner_sys_t filter_owner_sys_t;

typedef struct filter_owner_t
{
    void *sys;

    union
    {
        struct
        {
            picture_t * (*buffer_new)( filter_t * );
        } video;
        struct
        {
            subpicture_t * (*buffer_new)( filter_t * );
        } sub;
    };
} filter_owner_t;


/** Structure describing a filter
 * @warning BIG FAT WARNING : the code relies on the first 4 members of
 * filter_t and decoder_t to be the same, so if you have anything to add,
 * do it at the end of the structure.
 */
struct filter_t
{
    VLC_COMMON_MEMBERS

    /* Module properties */
    module_t *          p_module;
    filter_sys_t *      p_sys;

    /* Input format */
    es_format_t         fmt_in;

    /* Output format of filter */
    es_format_t         fmt_out;
    bool                b_allow_fmt_out_change;

    /* Filter configuration */
    config_chain_t *    p_cfg;

    union
    {
        /** Filter a picture (video filter) */
        picture_t * (*pf_video_filter)( filter_t *, picture_t * );

        /** Filter an audio block (audio filter) */
        block_t * (*pf_audio_filter)( filter_t *, block_t * );

        /** Blend a subpicture onto a picture (blend) */
        void (*pf_video_blend)( filter_t *,  picture_t *, const picture_t *,
                                 int, int, int );

        /** Generate a subpicture (sub source) */
        subpicture_t *(*pf_sub_source)( filter_t *, mtime_t );

        /** Filter a subpicture (sub filter) */
        subpicture_t *(*pf_sub_filter)( filter_t *, subpicture_t * );

        /** Render text (text render) */
        int (*pf_render)( filter_t *, subpicture_region_t *,
                          subpicture_region_t *, const vlc_fourcc_t * );
    };

    union
    {
        /* TODO: video filter drain */
        /** Drain (audio filter) */
        block_t *(*pf_audio_drain) ( filter_t * );
    };

    /** Flush
     *
     * Flush (i.e. discard) any internal buffer in a video or audio filter.
     */
    void (*pf_flush)( filter_t * );

    union
    {
        /** Filter mouse state (video filter).
         *
         * If non-NULL, you must convert from output to input formats:
         * - If VLC_SUCCESS is returned, the mouse state is propagated.
         * - Otherwise, the mouse change is not propagated.
         * If NULL, the mouse state is considered unchanged and will be
         * propagated. */
        int (*pf_video_mouse)( filter_t *, vlc_mouse_t *,
                               const vlc_mouse_t *p_old,
                               const vlc_mouse_t *p_new );
        int (*pf_sub_mouse)( filter_t *, const vlc_mouse_t *p_old,
                              const vlc_mouse_t *p_new,
                                             const video_format_t * );
    };

    /* Input attachments
     * XXX use filter_GetInputAttachments */
    int (*pf_get_attachments)( filter_t *, input_attachment_t ***, int * );

    /* Private structure for the owner of the decoder */
    filter_owner_t      owner;
};

/**
 * This function will return a new picture usable by p_filter as an output
 * buffer. You have to release it using picture_Release or by returning
 * it to the caller as a pf_video_filter return value.
 * Provided for convenience.
 *
 * \param p_filter filter_t object
 * \return new picture on success or NULL on failure
 */
static inline picture_t *filter_NewPicture( filter_t *p_filter )
{
    picture_t *pic = p_filter->owner.video.buffer_new( p_filter );
    if( pic == NULL )
        msg_Warn( p_filter, "can't get output picture" );
    return pic;
}

/**
 * Flush a filter
 *
 * This function will flush the state of a filter (audio or video).
 */
static inline void filter_Flush( filter_t *p_filter )
{
    if( p_filter->pf_flush != NULL )
        p_filter->pf_flush( p_filter );
}

/**
 * This function will drain, then flush an audio filter.
 */
static inline block_t *filter_DrainAudio( filter_t *p_filter )
{
    if( p_filter->pf_audio_drain )
        return p_filter->pf_audio_drain( p_filter );
    else
        return NULL;
}

/**
 * This function will return a new subpicture usable by p_filter as an output
 * buffer. You have to release it using subpicture_Delete or by returning it to
 * the caller as a pf_sub_source return value.
 * Provided for convenience.
 *
 * \param p_filter filter_t object
 * \return new subpicture
 */
static inline subpicture_t *filter_NewSubpicture( filter_t *p_filter )
{
    subpicture_t *subpic = p_filter->owner.sub.buffer_new( p_filter );
    if( subpic == NULL )
        msg_Warn( p_filter, "can't get output subpicture" );
    return subpic;
}

/**
 * This function gives all input attachments at once.
 *
 * You MUST release the returned values
 */
static inline int filter_GetInputAttachments( filter_t *p_filter,
                                              input_attachment_t ***ppp_attachment,
                                              int *pi_attachment )
{
    if( !p_filter->pf_get_attachments )
        return VLC_EGENERIC;
    return p_filter->pf_get_attachments( p_filter,
                                         ppp_attachment, pi_attachment );
}

/**
 * It creates a blend filter.
 *
 * Only the chroma properties of the dest format is used (chroma
 * type, rgb masks and shifts)
 */
VLC_API filter_t * filter_NewBlend( vlc_object_t *, const video_format_t *p_dst_chroma ) VLC_USED;

/**
 * It configures blend filter parameters that are allowed to changed
 * after the creation.
 */
VLC_API int filter_ConfigureBlend( filter_t *, int i_dst_width, int i_dst_height, const video_format_t *p_src );

/**
 * It blends a picture into another one.
 *
 * The input picture is not modified and not released.
 */
VLC_API int filter_Blend( filter_t *, picture_t *p_dst, int i_dst_x, int i_dst_y, const picture_t *p_src, int i_alpha );

/**
 * It destroys a blend filter created by filter_NewBlend.
 */
VLC_API void filter_DeleteBlend( filter_t * );

/**
 * Create a picture_t *(*)( filter_t *, picture_t * ) compatible wrapper
 * using a void (*)( filter_t *, picture_t *, picture_t * ) function
 *
 * Currently used by the chroma video filters
 */
#define VIDEO_FILTER_WRAPPER( name )                                    \
    static picture_t *name ## _Filter ( filter_t *p_filter,             \
                                        picture_t *p_pic )              \
    {                                                                   \
        picture_t *p_outpic = filter_NewPicture( p_filter );            \
        if( p_outpic )                                                  \
        {                                                               \
            name( p_filter, p_pic, p_outpic );                          \
            picture_CopyProperties( p_outpic, p_pic );                  \
        }                                                               \
        picture_Release( p_pic );                                       \
        return p_outpic;                                                \
    }

/**
 * Filter chain management API
 * The filter chain management API is used to dynamically construct filters
 * and add them in a chain.
 */

typedef struct filter_chain_t filter_chain_t;

/**
 * Create new filter chain
 *
 * \param p_object pointer to a vlc object
 * \param psz_capability vlc capability of filters in filter chain
 * \param b_allow_format_fmt_change allow changing of fmt
 * \return pointer to a filter chain
 */
VLC_API filter_chain_t * filter_chain_New( vlc_object_t *, const char *, bool )
VLC_USED;
#define filter_chain_New( a, b, c ) filter_chain_New( VLC_OBJECT( a ), b, c )

/**
 * Creates a new video filter chain.
 *
 * \param obj pointer to parent VLC object
 * \param change whether to allow changing the output format
 * \param owner owner video buffer callbacks
 * \return new filter chain, or NULL on error
 */
VLC_API filter_chain_t * filter_chain_NewVideo( vlc_object_t *obj, bool change,
                                                const filter_owner_t *owner )
VLC_USED;
#define filter_chain_NewVideo( a, b, c ) \
        filter_chain_NewVideo( VLC_OBJECT( a ), b, c )

/**
 * Delete filter chain will delete all filters in the chain and free all
 * allocated data. The pointer to the filter chain is then no longer valid.
 *
 * \param p_chain pointer to filter chain
 */
VLC_API void filter_chain_Delete( filter_chain_t * );

/**
 * Reset filter chain will delete all filters in the chain and
 * reset p_fmt_in and p_fmt_out to the new values.
 *
 * \param p_chain pointer to filter chain
 * \param p_fmt_in new fmt_in params
 * \param p_fmt_out new fmt_out params
 */
VLC_API void filter_chain_Reset( filter_chain_t *, const es_format_t *, const es_format_t * );

/**
 * Append filter to the end of the chain.
 *
 * \param chain filter chain to append a filter to
 * \param name filter name
 * \param fmt_in filter input format
 * \param fmt_out filter output format
 * \return a pointer to the filter or NULL on error
 */
VLC_API filter_t *filter_chain_AppendFilter(filter_chain_t *chain,
    const char *name, config_chain_t *cfg, const es_format_t *fmt_in,
    const es_format_t *fmt_out);

/**
 * Append new filter to filter chain from string.
 *
 * \param chain filter chain to append a filter to
 * \param str filters chain nul-terminated string
 */
VLC_API int filter_chain_AppendFromString(filter_chain_t *chain,
                                          const char *str);

/**
 * Delete filter from filter chain. This function also releases the filter
 * object and unloads the filter modules. The pointer to p_filter is no
 * longer valid after this function successfully returns.
 *
 * \param chain filter chain to remove the filter from
 * \param filter filter to remove from the chain and delete
 */
VLC_API void filter_chain_DeleteFilter(filter_chain_t *chain,
                                       filter_t *filter);

/**
 * Get the number of filters in the filter chain.
 *
 * \param chain pointer to filter chain
 * \return number of filters in this filter chain
 */
VLC_API int filter_chain_GetLength(filter_chain_t *chain);

/**
 * Get last output format of the last element in the filter chain.
 *
 * \param chain filter chain
 */
VLC_API const es_format_t *filter_chain_GetFmtOut(filter_chain_t *chain);

/**
 * Apply the filter chain to a video picture.
 *
 * \param chain pointer to filter chain
 * \param pic picture to apply filters to
 * \return modified picture after applying all video filters
 */
VLC_API picture_t *filter_chain_VideoFilter(filter_chain_t *chain,
                                            picture_t *pic);

/**
 * Flush a video filter chain.
 */
VLC_API void filter_chain_VideoFlush( filter_chain_t * );

/**
 * Apply the filter chain to a audio block.
 * \bug Deal with block chains and document.
 *
 * \param chain pointer to filter chain
 * \param block audio frame to apply filters on
 * \return modified audio frame after applying all audio filters
 */
VLC_API block_t *filter_chain_AudioFilter(filter_chain_t *chain,
                                          block_t *block);

/**
 * Generate subpictures from a chain of subpicture source "filters".
 *
 * \param chain filter chain
 * \param display_date of subpictures
 */
void filter_chain_SubSource(filter_chain_t *chain, spu_t *,
                            mtime_t display_date);

/**
 * Apply filter chain to subpictures.
 *
 * \param chain filter chain
 * \param subpic subpicture to apply filters on
 * \return modified subpicture after applying all subpicture filters
 */
VLC_API subpicture_t *filter_chain_SubFilter(filter_chain_t *chain,
                                             subpicture_t *subpic);

/**
 * Apply the filter chain to a mouse state.
 *
 * It will be applied from the output to the input. It makes sense only
 * for a video filter chain.
 *
 * The vlc_mouse_t* pointers may be the same.
 */
VLC_API int filter_chain_MouseFilter( filter_chain_t *, vlc_mouse_t *, const vlc_mouse_t * );

/**
 * Inform the filter chain of mouse state.
 *
 * It makes sense only for a sub source chain.
 */
VLC_API int filter_chain_MouseEvent( filter_chain_t *, const vlc_mouse_t *, const video_format_t * );

int filter_chain_ForEach( filter_chain_t *chain,
                          int (*cb)( filter_t *, void * ), void *opaque );

/** @} */
#endif /* _VLC_FILTER_H */
