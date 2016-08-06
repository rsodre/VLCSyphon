/*
 syphonServer.m
 
 Created by rsodre on 05/aug/2016
 
 Copyright 2011 rsodre, bangnoise (Tom Butterworth) & vade (Anton Marini).
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <vlc_common.h>
#include <vlc_picture_pool.h>
#include <vlc_subpicture.h>
#include <vlc_opengl.h>
#include <vlc_memory.h>
#include <vlc_vout_display.h>

#include "opengl.h"

#   define VLCGL_TEXTURE_COUNT 1

typedef struct {
	GLuint   texture;
	unsigned format;
	unsigned type;
	unsigned width;
	unsigned height;
	
	float    alpha;
	
	float    top;
	float    left;
	float    bottom;
	float    right;
	
	float    tex_width;
	float    tex_height;
} gl_region_t;

struct vout_display_opengl_t {
	
	vlc_gl_t   *gl;
	
	video_format_t fmt;
	const vlc_chroma_description_t *chroma;
	
	int        tex_target;
	int        tex_format;
	int        tex_internal;
	int        tex_type;
	
	int        tex_width[PICTURE_PLANE_MAX];
	int        tex_height[PICTURE_PLANE_MAX];
	
	GLuint     texture[VLCGL_TEXTURE_COUNT][PICTURE_PLANE_MAX];
	
	int         region_count;
	gl_region_t *region;
	
	
	picture_pool_t *pool;
	
	/* index 0 for normal and 1 for subtitle overlay */
	GLuint     program[2];
	GLint      shader[3]; //3. is for the common vertex shader
	int        local_count;
	GLfloat    local_value[16];
	
	GLuint vertex_buffer_object;
	GLuint index_buffer_object;
	GLuint texture_buffer_object[PICTURE_PLANE_MAX];
	
	GLuint *subpicture_buffer_object;
	int    subpicture_buffer_object_count;
	
	/* Shader variables commands*/
#ifdef SUPPORTS_SHADERS
	PFNGLGETUNIFORMLOCATIONPROC      GetUniformLocation;
	PFNGLGETATTRIBLOCATIONPROC       GetAttribLocation;
	PFNGLVERTEXATTRIBPOINTERPROC     VertexAttribPointer;
	PFNGLENABLEVERTEXATTRIBARRAYPROC EnableVertexAttribArray;
	
	PFNGLUNIFORMMATRIX4FVPROC   UniformMatrix4fv;
	PFNGLUNIFORM4FVPROC         Uniform4fv;
	PFNGLUNIFORM4FPROC          Uniform4f;
	PFNGLUNIFORM1IPROC          Uniform1i;
	
	/* Shader command */
	PFNGLCREATESHADERPROC CreateShader;
	PFNGLSHADERSOURCEPROC ShaderSource;
	PFNGLCOMPILESHADERPROC CompileShader;
	PFNGLDELETESHADERPROC   DeleteShader;
	
	PFNGLCREATEPROGRAMPROC CreateProgram;
	PFNGLLINKPROGRAMPROC   LinkProgram;
	PFNGLUSEPROGRAMPROC    UseProgram;
	PFNGLDELETEPROGRAMPROC DeleteProgram;
	
	PFNGLATTACHSHADERPROC  AttachShader;
	
	/* Shader log commands */
	PFNGLGETPROGRAMIVPROC  GetProgramiv;
	PFNGLGETPROGRAMINFOLOGPROC GetProgramInfoLog;
	PFNGLGETSHADERIVPROC   GetShaderiv;
	PFNGLGETSHADERINFOLOGPROC GetShaderInfoLog;
	
	PFNGLGENBUFFERSPROC    GenBuffers;
	PFNGLBINDBUFFERPROC    BindBuffer;
	PFNGLBUFFERDATAPROC    BufferData;
	PFNGLDELETEBUFFERSPROC DeleteBuffers;
#endif
	
#if defined(_WIN32)
	PFNGLACTIVETEXTUREPROC  ActiveTexture;
	PFNGLCLIENTACTIVETEXTUREPROC  ClientActiveTexture;
#endif
	
	
	/* multitexture */
	bool use_multitexture;
	
	/* Non-power-of-2 texture size support */
	bool supports_npot;
	
	uint8_t *texture_temp_buf;
	int      texture_temp_buf_size;
};





#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>
#import <Syphon/Syphon.h>
#include "syphonServer.h"

#define SERVER_NAME		@"Video"

// Singleton
SyphonServer *mSyphon = NULL;

void syphon_open( bool privateServer )
{
	@autoreleasepool
	{
//		NSString *title = [NSString stringWithCString:name
//											 encoding:[NSString defaultCStringEncoding]];
		if (!mSyphon)
		{
			NSDictionary *options = nil;
			if ( privateServer )
				// http://rypress.com/tutorials/objective-c/data-types/nsdictionary.html
				options = @{ SyphonServerOptionIsPrivate : [NSNumber numberWithBool:TRUE] };
			mSyphon = [[SyphonServer alloc] initWithName:SERVER_NAME context:CGLGetCurrentContext() options:options];
		}
		else
		{
			[mSyphon setName:SERVER_NAME];
		}
	}
}

void syphon_close()
{
	@autoreleasepool {
		if (mSyphon != NULL)
		{
			[mSyphon stop];
			[mSyphon release];
			mSyphon = nil;
		}
	}
}

bool syphon_enabled()
{
	return ( mSyphon != NULL );
}

void syphon_publish( GLuint target, GLuint texID, int width, int height, bool flipped )
{
	@autoreleasepool
	{
		if(mSyphon != NULL && texID)
		{
			if (!mSyphon)
			{
				mSyphon = [[SyphonServer alloc] initWithName:SERVER_NAME context:CGLGetCurrentContext() options:nil];
			}
			[mSyphon publishFrameTexture:texID
						   textureTarget:target
							 imageRegion:NSMakeRect(0, 0, width, height)
					   textureDimensions:NSMakeSize(width, height)
								 flipped:flipped];
		} else {
//			std::cout<<"syphonServer is not setup, or texture is not properly backed.  Cannot draw.\n";
		}
	}
}


//std::string syphonServer::getName()
//{
//	std::string name;
//	if (mSyphon)
//	{
//		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
//		name = [[mSyphon name] cStringUsingEncoding:[NSString defaultCStringEncoding]];
//		[pool drain];
//	}
//	return name;
//}
//
//std::string syphonServer::getUUID()
//{
//	if (!mSyphon)
//		return "";
//	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
//	NSString * u = [mSyphon.serverDescription objectForKey:SyphonServerDescriptionUUIDKey];
//	std::string uuid = std::string( [u UTF8String] );
//	[pool drain];
//	return uuid;
//}
//
//void syphonServer::publishScreen()
//{
//	ci::gl::Texture mTex =  ci::gl::Texture(ci::app::copyWindowSurface());
//	this->publishTexture( mTex );
//}




void syphon_display_opengl_Display(vout_display_opengl_t *vgl, const video_format_t *source)
{
	if (vlc_gl_Lock(vgl->gl))
		return;
	
	for (int i = 0; i < vgl->region_count; i++)
	{
		gl_region_t *glr = &vgl->region[i];
		const GLfloat vertexCoord[] = {
			glr->left,  glr->top,
			glr->left,  glr->bottom,
			glr->right, glr->top,
			glr->right, glr->bottom,
		};
		const GLfloat textureCoord[] = {
			0.0, 0.0,
			0.0, glr->tex_height,
			glr->tex_width, 0.0,
			glr->tex_width, glr->tex_height,
		};
		
		// ROGER -- SYPHON
		syphon_publish(GL_TEXTURE_2D, glr->texture, glr->tex_width, glr->tex_height, false);
	}
}

