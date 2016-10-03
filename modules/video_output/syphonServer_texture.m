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

#define SYPHON_SERVER
#include <vlc_vout_display.h>
#include "opengl.c"

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>
#import <Syphon/Syphon.h>
#include "syphonServer.h"

#define SERVER_NAME		@"Video"

// Singleton
SyphonServer * mSyphon = NULL;
GLuint myTex = 0;
bool newTex = false;

void syphon_open( CGLContextObj context )
{
	@autoreleasepool
	{
		//		NSString *title = [NSString stringWithCString:name
		//											 encoding:[NSString defaultCStringEncoding]];
		if (mSyphon == NULL)
		{
			//ns_log_to_file();
			//			glGenTextures(1, &myTex);
			newTex = true;
			
			if (context == nil)
				context = CGLGetCurrentContext();
			
			NSLog(@">>> START SERVER ctx [%ld] current [%ld]",(long)context,(long)CGLGetCurrentContext());
			mSyphon = [[SyphonServer alloc] initWithName:SERVER_NAME context:context options:nil];
		}
		//		else
		//		{
		//			[mSyphon setName:SERVER_NAME];
		//		}
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
		if (myTex > 0)
		{
			glDeleteTextures(1, &myTex);
			myTex = 0;
		}
	}
}

bool syphon_enabled()
{
	return ( mSyphon != NULL );
}

void syphon_publish( GLuint target, GLuint texID, int width, int height, bool flipped )
{
	syphon_publish_area( target, texID, width, height, 0, 0, width, height, flipped );
}

void syphon_publish_area( GLuint target, GLuint texID, int width, int height, int x, int y, int w, int h, bool flipped )
{
	@autoreleasepool
	{
		if (texID == 0 || width == 0 || height == 0 || w == 0 || h == 0)
			return;
		
		if (mSyphon == NULL)
		{
			syphon_open(nil);
		}
		
		if(mSyphon != NULL)
		{
			//			[mSyphon publishFrameTexture:texID
			//						   textureTarget:target
			//							 imageRegion:NSMakeRect(x, y, w, h)
			//					   textureDimensions:NSMakeSize(width, height)
			//								 flipped:flipped];
			[mSyphon publishRenderBlock:^{
				glClearColor( 1,0,0,1 );
				glClear( GL_COLOR_BUFFER_BIT );
			}
								   size:NSMakeSize(width, height) ];
		}
	}
}

void ns_log_to_file()
{
	@autoreleasepool
	{
		NSString *logPath = [NSHomeDirectory() stringByAppendingPathComponent:@"console.txt"];
		freopen([logPath fileSystemRepresentation],"a+",stderr);
		NSLog(@">>> START LOG");
	}
}



//////////////////////////////////////
//
// From macosx.m
//
//static CGLContextObj OpenglGetContextObj (vlc_gl_t *gl);
//
// From macosx.m
//
//////////////////////////////////////


//void vlc_syphon_open(vout_display_sys_t *sys)
//{
//	ns_log_to_file();
//	if (sys->glView)
//	{
//		NSLog(@"sys");
//		if ([sys->glView respondsToSelector:@selector(openGLContext)])
//		{
//			NSLog(@"sys->glView!");
//			NSOpenGLContext *context = [sys->glView openGLContext];
//			NSLog(@"ctx [%ld]",(long)context);
//			if (context)
//				syphon_open([context CGLContextObj], false);
//		}
//	}
//	NSLog(@"Open!");
//}

void vlc_syphon_publish(vout_display_opengl_t *vgl, const video_format_t *source)
{
	@autoreleasepool
	{
		if (vlc_gl_Lock(vgl->gl))
			return;
		
		int w = source->i_width;
		int h = source->i_height;
		
		//		int target = vgl->tex_target;
		//		int internal = vgl->tex_internal;
		//		int format = vgl->tex_format;
		//		int type = vgl->tex_type
		
		int target = GL_TEXTURE_RECTANGLE_ARB;
		//		int target = GL_TEXTURE_2D;
		int internal = GL_RGB;
		int format = GL_RGB;
		int type = GL_UNSIGNED_BYTE;
		int bpp = (format == GL_RGBA ? 4 : 3);
		//internal = bpp;
		
		NSLog(@"Syphon: Publish wh [%d,%d] bpp [%d] GL_RGBA [%d]",w,h,bpp,GL_RGBA);
		
		// Copy texture from framebuffer
		// https://www.opengl.org/sdk/docs/man/html/glCopyTexSubImage2D.xhtml
		
		// setup texture
		if (newTex)
			glGenTextures(1, &myTex);
		if (myTex == 0)
			return;
		glEnable(target);
		glBindTexture(target, myTex);
		
		if (newTex)
		{
			NSLog(@"Syphon: ############## Setup new texture");
			newTex = false;
			
			glTexParameteri(target, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			glTexParameteri(target, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
			glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
			
			glTexImage2D(target, 0, internal, w, h, 0, format, type, NULL);
			
			glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
			glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
			glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
			glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);
			//
			//			size_t sz = (w * h * bpp);
			//			GLubyte data[sz];
			//			memset(data, sz, 0xff);
			//			glTexImage2D(target,0,internal,w,h,0,format,type,&data[0]);
		}
		
		glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
		glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
		glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
		glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);
		
		glPixelStorei(GL_PACK_ALIGNMENT, 4);
		glPixelStorei(GL_PACK_ROW_LENGTH, 0);
		glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
		glPixelStorei(GL_PACK_SKIP_ROWS, 0);
		
		// Copy from current buffer
		glReadBuffer(GL_BACK);
		glCopyTexSubImage2D(target, 0, 0, 0, 0, 0, w, h);
		// https://www.khronos.org/opengles/sdk/docs/man/xhtml/glCopyTexImage2D.xml
		//		glCopyTexImage2D(target, 0, internal, 0, 0, w, h, 0);
		
		glBindTexture(target, 0);
		glDisable(target);
		
		syphon_publish(target, myTex, w, h, false);
		
		
		
		//		GLint bw, bh, bi, bs;
		//		glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &bw);
		//		glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &bh);
		//		glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_INTERNAL_FORMAT, &bi);
		//		glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_SAMPLES, &bs);
		//		NSLog(@"Syphon: Buffer w [%d] h [%d] internal [%d] samples [%d]",(int)bw,(int)bh,(int)bi,(int)bs);
		
		
		
		//		for (unsigned j = 0; j < vgl->chroma->plane_count; j++)
		//		{
		//			NSLog(@"Syphon: planes [%d/%d] wh [%d,%d]",
		//				  j,vgl->chroma->plane_count,
		//				  vgl->tex_width[j],vgl->tex_height[j]);
		//
		//			int w = vgl->tex_width[j];
		//			int h = vgl->tex_height[j];
		//			if (w == source->i_width)
		//			{
		//				NSLog(@"Syphon: Publishing...");
		//				syphon_publish(target, vgl->texture[0][j], w, h, false);
		//				break;
		//			}
		//		}
		
		//		syphon_publish(target, vgl->texture[0][0], w, h, false);
		
		
		vlc_gl_Unlock(vgl->gl);
		
		NSLog(@"Published!");
	}
}












