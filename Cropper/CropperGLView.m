#import "CropperGLView.h"
#import <OpenGL/OpenGL.h>
#import <OpenGL/glu.h>
#import <Syphon/Syphon.h>

@implementation CropperGLView

- (CVReturn) getFrameForTime:(const CVTimeStamp*)outputTime
{
	[self drawView];
	return kCVReturnSuccess;
}

static CVReturn DisplayLinkOutputCallback(CVDisplayLinkRef displayLink,
                                          const CVTimeStamp *now,
                                          const CVTimeStamp *outputTime,
                                          CVOptionFlags flagsIn,
                                          CVOptionFlags *flagsOut,
                                          void *displayLinkContext)
{
    CropperGLView *glView = (__bridge CropperGLView *)displayLinkContext;
    CVReturn result = [glView getFrameForTime:outputTime];
    return result;
}

- (void)awakeFromNib
{
    NSOpenGLPixelFormatAttribute attributes[] = { NSOpenGLPFADoubleBuffer, 0 };
    self.pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    self.openGLContext = [[NSOpenGLContext alloc] initWithFormat:self.pixelFormat shareContext:nil];
}

- (void)dealloc
{
    CVDisplayLinkStop(_displayLink);
    CVDisplayLinkRelease(_displayLink);
}

- (void)prepareOpenGL
{
    [super prepareOpenGL];
    
    [self initGL];
    
    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
    CVDisplayLinkSetOutputCallback(_displayLink, DisplayLinkOutputCallback, (__bridge void *)(self));
    CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(_displayLink, self.openGLContext.CGLContextObj, self.pixelFormat.CGLPixelFormatObj);
    CVDisplayLinkStart(_displayLink);
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowWillClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:self.window];
}

- (void)windowWillClose:(NSNotification *)notification
{
    CVDisplayLinkStop(_displayLink);
}

- (void)initGL
{
    [self.openGLContext makeCurrentContext];
    
    GLint interval = 1;
    [self.openGLContext setValues:&interval forParameter:NSOpenGLCPSwapInterval];
    
    _margins[0] = 0.5f;
    _margins[1] = 0.2f;
    _margins[2] = 0.1f;
    _margins[3] = 0.1f;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [self drawView];
}

- (void)drawView
{
    CGLLockContext(self.openGLContext.CGLContextObj);
    
    [self.openGLContext makeCurrentContext];
    
    CGSize size = self.frame.size;
    glViewport(0, 0, size.width, size.height);

    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glLoadIdentity();
    
    float edges[] =
    {
        1.0f - _margins[0] * 2,
        1.0f - _margins[1] * 2,
        -1.0f + _margins[2] * 2,
        -1.0f + _margins[3] * 2
    };

    if (self.syphonClient)
    {
        SyphonImage *image = [self.syphonClient newFrameImageForContext:self.openGLContext.CGLContextObj];
        if (image)
        {
            float texEdges[] =
            {
                image.textureSize.height * (1.0f - _margins[0]),
                image.textureSize.width * (1.0f - _margins[1]),
                image.textureSize.height * _margins[2],
                image.textureSize.width * _margins[3]
            };
            
            glEnable(GL_TEXTURE_RECTANGLE_ARB);
            
            glBindTexture(GL_TEXTURE_RECTANGLE_ARB, image.textureName);
            
            glBegin(GL_QUADS);
            
            glColor3f(1, 1, 1);
            
            glTexCoord2f(texEdges[3], texEdges[2]);
            glVertex2f(edges[3], edges[2]);
            
            glTexCoord2f(texEdges[1], texEdges[2]);
            glVertex2f(edges[1], edges[2]);
            
            glTexCoord2f(texEdges[1], texEdges[0]);
            glVertex2f(edges[1], edges[0]);
            
            glTexCoord2f(texEdges[3], texEdges[0]);
            glVertex2f(edges[3], edges[0]);
            
            glEnd();
            
            glDisable(GL_TEXTURE_RECTANGLE_ARB);
        }
    }
    
    glColor3f(1, 1, 1);

    glPushMatrix();
    glTranslatef(0.5f * (edges[1] + edges[3]), 0, 0);
    
    glPushMatrix();
    glTranslatef(0, edges[0], 0);
    glBegin(GL_TRIANGLES);
    glVertex2f(0, 0);
    glVertex2f(-0.05f, -0.1f);
    glVertex2f(+0.05f, -0.1f);
    glEnd();
    glPopMatrix();

    glPushMatrix();
    glTranslatef(0, edges[2], 0);
    glBegin(GL_TRIANGLES);
    glVertex2f(0, 0);
    glVertex2f(-0.05f, 0.1f);
    glVertex2f(+0.05f, 0.1f);
    glEnd();
    glPopMatrix();
    
    glPopMatrix();

    glPushMatrix();
    glTranslatef(0, 0.5f * (edges[0] + edges[2]), 0);
    
    glPushMatrix();
    glTranslatef(edges[1], 0, 0);
    glBegin(GL_TRIANGLES);
    glVertex2f(0, 0);
    glVertex2f(-0.1f, -0.05f);
    glVertex2f(-0.1f, +0.05f);
    glEnd();
    glPopMatrix();
    
    glPushMatrix();
    glTranslatef(edges[3], 0, 0);
    glBegin(GL_TRIANGLES);
    glVertex2f(0, 0);
    glVertex2f(0.1f, -0.05f);
    glVertex2f(0.1f, +0.05f);
    glEnd();
    glPopMatrix();
    
    glPopMatrix();
    
    CGLFlushDrawable(self.openGLContext.CGLContextObj);
    CGLUnlockContext(self.openGLContext.CGLContextObj);
}

@end
