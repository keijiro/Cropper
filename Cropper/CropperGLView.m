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
}


- (void)drawRect:(NSRect)dirtyRect
{
    [self drawView];
}


- (void)drawView
{
    CGLLockContext(self.openGLContext.CGLContextObj);
    
    [self.openGLContext makeCurrentContext];

    glViewport(0, 0, self.frame.size.width, self.frame.size.height);

    glClearColor(0.5f, 0.5f, 0.5f, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glLoadIdentity();

    if (self.syphonClient)
    {
        SyphonImage *image = [self.syphonClient newFrameImageForContext:self.openGLContext.CGLContextObj];
        if (image)
        {
            glEnable(GL_TEXTURE_RECTANGLE_ARB);
            
            glBindTexture(GL_TEXTURE_RECTANGLE_ARB, image.textureName);
            
            glBegin(GL_QUADS);
            
            glColor3f(1, 1, 1);
            
            glTexCoord2f(0, 0);
            glVertex2f(-1, -1);
            
            glTexCoord2f(image.textureSize.width, 0);
            glVertex2f(+1, -1);
            
            glTexCoord2f(image.textureSize.width, image.textureSize.height);
            glVertex2f(+1, +1);
            
            glTexCoord2f(0, image.textureSize.height);
            glVertex2f(-1, +1);
            
            glEnd();
            
            glDisable(GL_TEXTURE_RECTANGLE_ARB);
        }
    }
    
    glBegin(GL_TRIANGLES);
    glColor3f(0.3f, 0.3f, 0.3f);
    
    glVertex2f(0, -1);
    glVertex2f(-0.1f, -0.8f);
    glVertex2f(0.1f, -0.8f);
    
    glVertex2f(0, 1);
    glVertex2f(-0.1f, 0.8f);
    glVertex2f(0.1f, 0.8f);
    
    glVertex2f(-1, 0);
    glVertex2f(-0.8f, 0.1f);
    glVertex2f(-0.8f, -0.1f);
    
    glVertex2f(1, 0);
    glVertex2f(0.8f, 0.1f);
    glVertex2f(0.8f, -0.1f);
 
    glEnd();
    
    CGLFlushDrawable(self.openGLContext.CGLContextObj);
    CGLUnlockContext(self.openGLContext.CGLContextObj);
}

@end
