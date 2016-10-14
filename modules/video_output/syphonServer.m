/*
 syphonServer.m
 
 Created by Roger Sodre on 05/aug/2016
 
 Syphon Copyright 2011 bangnoise (Tom Butterworth) & vade (Anton Marini).
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


//////////////////////////////////////////////
//
// LOG
//
#define SYPHON_LOG

void syphon_log_to_file()
{
#ifdef SYPHON_LOG
	@autoreleasepool
	{
		NSString *logPath = [NSHomeDirectory() stringByAppendingPathComponent:@"console.txt"];
		freopen([logPath fileSystemRepresentation],"a+",stderr);
		SyphonLog(@">>> START LOG");
	}
#endif
}

// https://code.tutsplus.com/tutorials/quick-tip-customize-nslog-for-easier-debugging--mobile-19066
void SyphonLog(NSString *format, ...)
{
#ifdef SYPHON_LOG
	va_list ap;
	va_start (ap, format);
	if (![format hasSuffix: @"\n"])
		format = [format stringByAppendingString: @"\n"];
	NSString *body = [[NSString alloc] initWithFormat:format arguments:ap];
	NSLog(@"%@",body);
	va_end (ap);
#endif
}






///////////////////////////////////////////////
//
// Syphon
//
// Singleton
SyphonServer * mSyphon = nil;
bool mOpen = false;

void syphon_close(bool destroy)
{
	@autoreleasepool {
		if (mSyphon != nil && destroy)
		{
			[mSyphon stop];
			[mSyphon release];
			mSyphon = nil;
		}
		mOpen = false;
	}
}

void syphon_open( CGLContextObj context )
{
	@autoreleasepool
	{
		syphon_close(true);
		
		if (context == nil)
			context = CGLGetCurrentContext();
		
		SyphonLog(@">>> START SERVER ctx [%ld] current [%ld]",(long)context,(long)CGLGetCurrentContext());
		mSyphon = [[SyphonServer alloc] initWithName:SERVER_NAME context:context options:nil];
		mOpen = (mSyphon != nil);
	}
}

/*
void syphon_publish( GLuint target, GLuint texID, int width, int height, bool flipped )
{
	syphon_publish_area( target, texID, width, height, 0, 0, width, height, flipped );
}

void syphon_publish_area( GLuint target, GLuint texID, int width, int height, int x, int y, int w, int h, bool flipped )
{
	@autoreleasepool
	{
		if (mSyphon == nil || texID == 0 || width == 0 || height == 0 || w == 0 || h == 0)
			return;
		
		[mSyphon publishFrameTexture:texID
					   textureTarget:target
						 imageRegion:NSMakeRect(x, y, w, h)
				   textureDimensions:NSMakeSize(width, height)
							 flipped:flipped];
//		[mSyphon publishRenderBlock:^{
//			glClearColor( 1,0,0,1 );
//			glClear( GL_COLOR_BUFFER_BIT );
//		}
//							   size:NSMakeSize(width, height) ];
	}
}
*/




///////////////////////////////////////////////////////
//
// FROM opengl.c
//

int syphon_display_opengl_Display(vout_display_opengl_t *vgl,
						const video_format_t *source)
{
	__block int error = VLC_SUCCESS;
	
	@autoreleasepool
	{
		if (vlc_gl_Lock(vgl->gl))
			return VLC_EGENERIC;
		
		SyphonLog(@"Publishing block...");
		
		if (mSyphon == nil || !mOpen)
			return VLC_EGENERIC;
		
		int width = source->i_width;
		int height = source->i_height;

		[mSyphon publishRenderBlock:^{
			
			glClearColor( 1,0,0,1 );
			glClear( GL_COLOR_BUFFER_BIT );

			///////////////////////////////////////////////////////
			//
			// FROM opengl.c
			// vout_display_opengl_Display()
			//
			
			/* Why drawing here and not in Render()? Because this way, the
			 OpenGL providers can call vout_display_opengl_Display to force redraw.i
			 Currently, the OS X provider uses it to get a smooth window resizing */
			glClear(GL_COLOR_BUFFER_BIT);
			
			/* Draw the picture */
			float left[PICTURE_PLANE_MAX];
			float top[PICTURE_PLANE_MAX];
			float right[PICTURE_PLANE_MAX];
			float bottom[PICTURE_PLANE_MAX];
			for (unsigned j = 0; j < vgl->chroma->plane_count; j++) {
				/* glTexCoord works differently with GL_TEXTURE_2D and
				 GL_TEXTURE_RECTANGLE_EXT */
				float scale_w, scale_h;
				
				if (vgl->tex_target == GL_TEXTURE_2D) {
					scale_w = (float)vgl->chroma->p[j].w.num / vgl->chroma->p[j].w.den / vgl->tex_width[j];
					scale_h = (float)vgl->chroma->p[j].h.num / vgl->chroma->p[j].h.den / vgl->tex_height[j];
					
				} else {
					scale_w = 1.0;
					scale_h = 1.0;
				}
				/* Warning: if NPOT is not supported a larger texture is
				 allocated. This will cause right and bottom coordinates to
				 land on the edge of two texels with the texels to the
				 right/bottom uninitialized by the call to
				 glTexSubImage2D. This might cause a green line to appear on
				 the right/bottom of the display.
				 There are two possible solutions:
				 - Manually mirror the edges of the texture.
				 - Add a "-1" when computing right and bottom, however the
				 last row/column might not be displayed at all.
				 */
				left[j]   = (source->i_x_offset +                       0 ) * scale_w;
				top[j]    = (source->i_y_offset +                       0 ) * scale_h;
				right[j]  = (source->i_x_offset + source->i_visible_width ) * scale_w;
				bottom[j] = (source->i_y_offset + source->i_visible_height) * scale_h;
			}
			
#ifdef SUPPORTS_SHADERS
			if (vgl->program[0] && (vgl->chroma->plane_count == 3 || vgl->chroma->plane_count == 1)){
				NSLog(@"syphon_DrawWithShaders program 0 [%d] plane_count [%d]",vgl->program[0],vgl->chroma->plane_count);
				DrawWithShaders(vgl, left, top, right, bottom, 0);
			}else if (vgl->program[1] && vgl->chroma->plane_count == 1){
				NSLog(@"syphon_DrawWithShaders program 1 [%d] plane_count [%d]",vgl->program[1],vgl->chroma->plane_count);
				DrawWithShaders(vgl, left, top, right, bottom, 1);
			}else
#endif
			{
#ifdef SUPPORTS_FIXED_PIPELINE
				NSLog(@"syphon_DrawWithoutShaders orientation [%d]",vgl->fmt.orientation);
				DrawWithoutShaders(vgl, left, top, right, bottom);
#endif
			}
			
			/* Draw the subpictures */
			if (vgl->program[1]) {
#ifdef SUPPORTS_SHADERS
				// Change the program for overlays
				vgl->UseProgram(vgl->program[1]);
				vgl->Uniform1i(vgl->GetUniformLocation(vgl->program[1], "Texture"), 0);
#endif
			}
			
#ifdef SUPPORTS_FIXED_PIPELINE
			glEnable(GL_TEXTURE_2D);
#endif
			glEnable(GL_BLEND);
			glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
			
#ifdef SUPPORTS_SHADERS
			/* We need two buffer objects for each region: for vertex and texture coordinates. */
			if (2 * vgl->region_count > vgl->subpicture_buffer_object_count) {
				if (vgl->subpicture_buffer_object_count > 0)
					vgl->DeleteBuffers(vgl->subpicture_buffer_object_count, vgl->subpicture_buffer_object);
				vgl->subpicture_buffer_object_count = 0;
				
				int new_count = 2 * vgl->region_count;
				vgl->subpicture_buffer_object = realloc_or_free(vgl->subpicture_buffer_object, new_count * sizeof(GLuint));
				if (!vgl->subpicture_buffer_object) {
					vlc_gl_Unlock(vgl->gl);
					error = VLC_ENOMEM;
					return;
				}
				
				vgl->subpicture_buffer_object_count = new_count;
				vgl->GenBuffers(vgl->subpicture_buffer_object_count, vgl->subpicture_buffer_object);
			}
#endif
			
			glActiveTexture(GL_TEXTURE0 + 0);
			glClientActiveTexture(GL_TEXTURE0 + 0);
			for (int i = 0; i < vgl->region_count; i++) {
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
				
				glBindTexture(GL_TEXTURE_2D, glr->texture);
				if (vgl->program[1]) {
#ifdef SUPPORTS_SHADERS
					vgl->Uniform4f(vgl->GetUniformLocation(vgl->program[1], "FillColor"), 1.0f, 1.0f, 1.0f, glr->alpha);
					
					vgl->BindBuffer(GL_ARRAY_BUFFER, vgl->subpicture_buffer_object[2 * i]);
					vgl->BufferData(GL_ARRAY_BUFFER, sizeof(textureCoord), textureCoord, GL_STATIC_DRAW);
					vgl->EnableVertexAttribArray(vgl->GetAttribLocation(vgl->program[1], "MultiTexCoord0"));
					vgl->VertexAttribPointer(vgl->GetAttribLocation(vgl->program[1], "MultiTexCoord0"), 2, GL_FLOAT, 0, 0, 0);
					
					vgl->BindBuffer(GL_ARRAY_BUFFER, vgl->subpicture_buffer_object[2 * i + 1]);
					vgl->BufferData(GL_ARRAY_BUFFER, sizeof(vertexCoord), vertexCoord, GL_STATIC_DRAW);
					vgl->EnableVertexAttribArray(vgl->GetAttribLocation(vgl->program[1], "VertexPosition"));
					vgl->VertexAttribPointer(vgl->GetAttribLocation(vgl->program[1], "VertexPosition"), 2, GL_FLOAT, 0, 0, 0);
					
					// Subpictures have the correct orientation:
					vgl->UniformMatrix4fv(vgl->GetUniformLocation(vgl->program[1], "OrientationMatrix"), 1, GL_FALSE, identity);
#endif
				} else {
#ifdef SUPPORTS_FIXED_PIPELINE
					glEnableClientState(GL_VERTEX_ARRAY);
					glEnableClientState(GL_TEXTURE_COORD_ARRAY);
					glColor4f(1.0f, 1.0f, 1.0f, glr->alpha);
					glTexCoordPointer(2, GL_FLOAT, 0, textureCoord);
					glVertexPointer(2, GL_FLOAT, 0, vertexCoord);
#endif
				}
				
				glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
				
				if (!vgl->program[1]) {
#ifdef SUPPORTS_FIXED_PIPELINE
					glDisableClientState(GL_TEXTURE_COORD_ARRAY);
					glDisableClientState(GL_VERTEX_ARRAY);
#endif
				}
			}
			glDisable(GL_BLEND);
#ifdef SUPPORTS_FIXED_PIPELINE
			glDisable(GL_TEXTURE_2D);
#endif
		
			/* Display */
			//vlc_gl_Swap(vgl->gl);

			//
			// FROM opengl.c
			// vout_display_opengl_Display()
			//
			///////////////////////////////////////////////////////

		}
							   size:NSMakeSize(width, height) ];
		
		vlc_gl_Unlock(vgl->gl);
		
		
		SyphonLog(@"Published!");
	}
	
	return error;
}



