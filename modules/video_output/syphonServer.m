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


//////////////////////////////////////////////
//
// LOG
//
//#define SYPHON_LOG

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
	NSLog(body);
	va_end (ap);
#endif
}






///////////////////////////////////////////////
//
// Syphon
//
// Singleton
SyphonServer * mSyphon = NULL;

void syphon_open( CGLContextObj context )
{
	@autoreleasepool
	{
//		NSString *title = [NSString stringWithCString:name
//											 encoding:[NSString defaultCStringEncoding]];
		if (mSyphon == NULL)
		{
			if (context == nil)
				context = CGLGetCurrentContext();
			
			SyphonLog(@">>> START SERVER ctx [%ld] current [%ld]",(long)context,(long)CGLGetCurrentContext());
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
			[mSyphon publishFrameTexture:texID
						   textureTarget:target
							 imageRegion:NSMakeRect(x, y, w, h)
					   textureDimensions:NSMakeSize(width, height)
								 flipped:flipped];
//			[mSyphon publishRenderBlock:^{
//				glClearColor( 1,0,0,1 );
//				glClear( GL_COLOR_BUFFER_BIT );
//			}
//								   size:NSMakeSize(width, height) ];
		}
	}
}





///////////////////////////////////////////////////////
//
// FROM opengl.c
//

static const GLfloat identity[] = {
	1.0f, 0.0f, 0.0f, 0.0f,
	0.0f, 1.0f, 0.0f, 0.0f,
	0.0f, 0.0f, 1.0f, 0.0f,
	0.0f, 0.0f, 0.0f, 1.0f
};

#ifdef SUPPORTS_FIXED_PIPELINE
static void syphon_DrawWithoutShaders(vout_display_opengl_t *vgl,
							   float *left, float *top, float *right, float *bottom)
{
	static const GLfloat vertexCoord[] = {
		-1.0f, -1.0f,
		1.0f, -1.0f,
		-1.0f,  1.0f,
		1.0f,  1.0f,
	};
	
	const GLfloat textureCoord[] = {
		left[0],  bottom[0],
		right[0], bottom[0],
		left[0],  top[0],
		right[0], top[0]
	};
	
	GLfloat transformMatrix[16];
	orientationTransformMatrix(transformMatrix, vgl->fmt.orientation);
	
	glPushMatrix();
	glMatrixMode(GL_MODELVIEW);
	glLoadMatrixf(transformMatrix);
	
	glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
	glEnable(vgl->tex_target);
	glActiveTexture(GL_TEXTURE0 + 0);
	glClientActiveTexture(GL_TEXTURE0 + 0);
	
	glBindTexture(vgl->tex_target, vgl->texture[0][0]);
	
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	
	glTexCoordPointer(2, GL_FLOAT, 0, textureCoord);
	glVertexPointer(2, GL_FLOAT, 0, vertexCoord);
	
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	glDisableClientState(GL_VERTEX_ARRAY);
	glDisable(vgl->tex_target);
	
	glPopMatrix();
	
}
#endif


static int syphon_BuildRectangle(unsigned nbPlanes,
						  GLfloat **vertexCoord, GLfloat **textureCoord, unsigned *nbVertices,
						  GLushort **indices, unsigned *nbIndices,
						  float *left, float *top, float *right, float *bottom)
{
	*nbVertices = 4;
	*nbIndices = 6;
	
	*vertexCoord = malloc(*nbVertices * 3 * sizeof(GLfloat));
	if (*vertexCoord == NULL)
		return VLC_ENOMEM;
	*textureCoord = malloc(nbPlanes * *nbVertices * 2 * sizeof(GLfloat));
	if (*textureCoord == NULL)
	{
		free(*vertexCoord);
		return VLC_ENOMEM;
	}
	*indices = malloc(*nbIndices * sizeof(GLushort));
	if (*indices == NULL)
	{
		free(*textureCoord);
		free(*vertexCoord);
		return VLC_ENOMEM;
	}
	
	static const GLfloat coord[] = {
		-1.0,    1.0,    -1.0f,
		-1.0,    -1.0,   -1.0f,
		1.0,     1.0,    -1.0f,
		1.0,     -1.0,   -1.0f
	};
	
	memcpy(*vertexCoord, coord, *nbVertices * 3 * sizeof(GLfloat));
	
	for (unsigned p = 0; p < nbPlanes; ++p)
	{
		const GLfloat tex[] = {
			left[p],  top[p],
			left[p],  bottom[p],
			right[p], top[p],
			right[p], bottom[p]
		};
		
		memcpy(*textureCoord + p * *nbVertices * 2, tex,
			   *nbVertices * 2 * sizeof(GLfloat));
	}
	
	const GLushort ind[] = {
		0, 1, 2,
		2, 1, 3
	};
	
	memcpy(*indices, ind, *nbIndices * sizeof(GLushort));
	
	return VLC_SUCCESS;
}


#ifdef SUPPORTS_SHADERS
static void syphon_DrawWithShaders(vout_display_opengl_t *vgl,
							float *left, float *top, float *right, float *bottom,
							int program)
{
	vgl->UseProgram(vgl->program[program]);
	if (program == 0) {
		if (vgl->chroma->plane_count == 3) {
			vgl->Uniform4fv(vgl->GetUniformLocation(vgl->program[0], "Coefficient"), 4, vgl->local_value);
			vgl->Uniform1i(vgl->GetUniformLocation(vgl->program[0], "Texture0"), 0);
			vgl->Uniform1i(vgl->GetUniformLocation(vgl->program[0], "Texture1"), 1);
			vgl->Uniform1i(vgl->GetUniformLocation(vgl->program[0], "Texture2"), 2);
		}
		else if (vgl->chroma->plane_count == 1) {
			vgl->Uniform1i(vgl->GetUniformLocation(vgl->program[0], "Texture0"), 0);
		}
	} else {
		vgl->Uniform1i(vgl->GetUniformLocation(vgl->program[1], "Texture0"), 0);
		vgl->Uniform4f(vgl->GetUniformLocation(vgl->program[1], "FillColor"), 1.0f, 1.0f, 1.0f, 1.0f);
	}
	
	GLfloat *vertexCoord, *textureCoord;
	GLushort *indices;
	unsigned nbVertices, nbIndices;
	
	int i_ret = syphon_BuildRectangle(vgl->chroma->plane_count,
							   &vertexCoord, &textureCoord, &nbVertices,
							   &indices, &nbIndices,
							   left, top, right, bottom);
	
	if (i_ret != VLC_SUCCESS)
		return;
	
	GLfloat projectionMatrix[16], viewMatrix[16],
	yRotMatrix[16], xRotMatrix[16],
	zoomMatrix[16], orientationMatrix[16];
	
	orientationTransformMatrix(orientationMatrix, vgl->fmt.orientation);
	
	for (unsigned j = 0; j < vgl->chroma->plane_count; j++) {
		glActiveTexture(GL_TEXTURE0+j);
		glClientActiveTexture(GL_TEXTURE0+j);
		glBindTexture(vgl->tex_target, vgl->texture[0][j]);
		
		vgl->BindBuffer(GL_ARRAY_BUFFER, vgl->texture_buffer_object[j]);
		vgl->BufferData(GL_ARRAY_BUFFER, nbVertices * 2 * sizeof(GLfloat),
						textureCoord + j * nbVertices * 2, GL_STATIC_DRAW);
		
		char attribute[20];
		snprintf(attribute, sizeof(attribute), "MultiTexCoord%1d", j);
		vgl->EnableVertexAttribArray(vgl->GetAttribLocation(vgl->program[program], attribute));
		vgl->VertexAttribPointer(vgl->GetAttribLocation(vgl->program[program], attribute), 2, GL_FLOAT, 0, 0, 0);
	}
	free(textureCoord);
	glActiveTexture(GL_TEXTURE0 + 0);
	glClientActiveTexture(GL_TEXTURE0 + 0);
	
	vgl->BindBuffer(GL_ARRAY_BUFFER, vgl->vertex_buffer_object);
	vgl->BufferData(GL_ARRAY_BUFFER, nbVertices * 3 * sizeof(GLfloat), vertexCoord, GL_STATIC_DRAW);
	free(vertexCoord);
	vgl->BindBuffer(GL_ELEMENT_ARRAY_BUFFER, vgl->index_buffer_object);
	vgl->BufferData(GL_ELEMENT_ARRAY_BUFFER, nbIndices * sizeof(GLushort), indices, GL_STATIC_DRAW);
	free(indices);
	vgl->EnableVertexAttribArray(vgl->GetAttribLocation(vgl->program[program], "VertexPosition"));
	vgl->VertexAttribPointer(vgl->GetAttribLocation(vgl->program[program], "VertexPosition"), 3, GL_FLOAT, 0, 0, 0);
	
	vgl->UniformMatrix4fv(vgl->GetUniformLocation(vgl->program[program], "OrientationMatrix"), 1, GL_FALSE, orientationMatrix);
	
	vgl->BindBuffer(GL_ELEMENT_ARRAY_BUFFER, vgl->index_buffer_object);
	glDrawElements(GL_TRIANGLES, nbIndices, GL_UNSIGNED_SHORT, 0);
}
#endif

int syphon_display_opengl_Display(vout_display_opengl_t *vgl,
						const video_format_t *source)
{
	__block int error = VLC_SUCCESS;
	
	@autoreleasepool
	{
		if (vlc_gl_Lock(vgl->gl))
			return VLC_EGENERIC;
		
		SyphonLog(@"Publishing block...");
		
		if (mSyphon == NULL)
			syphon_open(nil);
		
		if (mSyphon == NULL)
			return VLC_EGENERIC;
		
		int width = source->i_width;
		int height = source->i_height;

		[mSyphon publishRenderBlock:^{
			
			glDisable(GL_BLEND);
			glDisable(GL_DEPTH_TEST);
			glDepthMask(GL_FALSE);
			glEnable(GL_CULL_FACE);
			glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
			glClear(GL_COLOR_BUFFER_BIT);
			glColor4f(1.0f, 1.0f, 1.0f, 1.0f);

//			glEnable(GL_BLEND);
//			glBlendFunc(GL_SRC_ALPHA, GL_ZERO);
//			glBlendFunc(GL_ONE, GL_ZERO);

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
			if (vgl->program[0] && (vgl->chroma->plane_count == 3 || vgl->chroma->plane_count == 1))
				syphon_DrawWithShaders(vgl, left, top, right, bottom, 0);
			else if (vgl->program[1] && vgl->chroma->plane_count == 1)
				syphon_DrawWithShaders(vgl, left, top, right, bottom, 1);
			else
#endif
			{
#ifdef SUPPORTS_FIXED_PIPELINE
				syphon_DrawWithoutShaders(vgl, left, top, right, bottom);
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



