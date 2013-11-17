#import "CropperGLView.h"
#import "GLVX.h"
#import "glv.h"
#import "Syphon/Syphon.h"

#pragma mark
#pragma mark GLV interface

namespace
{
    using namespace glv;
    
    struct SyphonClientGLV : public GLV
    {
        View anchorView;
        SyphonImage *image;
        
        SyphonClientGLV()
        : image(nil)
        {
            colors().set(glv::StyleColor::WhiteOnBlack);
            
            *this << anchorView;
            
            anchorView.disable(DrawBack);
            anchorView.addHandler(Event::MouseDrag, Behavior::mouseResizeCorner);
            anchorView.addHandler(Event::MouseDrag, Behavior::mouseMove);
            
            anchorView << (new Label("CROPPING MODE"))->anchor(Place::CC).pos(Place::CC);
        }
        
        virtual void onDraw(GLV& g)
        {
            using namespace draw;
            
            if (image)
            {
                auto window = anchorView.rect();
                
                glDisable(GL_BLEND);
                glEnable(GL_TEXTURE_RECTANGLE_ARB);
                glBindTexture(GL_TEXTURE_RECTANGLE_ARB, image.textureName);
                
                glBegin(GL_QUADS);
                
                glColor3f(1, 1, 1);
                
                glTexCoord2f(window.left(), window.top());
                glVertex2f(window.left(), window.top());
                
                glTexCoord2f(window.right(), window.top());
                glVertex2f(window.right(), window.top());
                
                glTexCoord2f(window.right(), window.bottom());
                glVertex2f(window.right(), window.bottom());
                
                glTexCoord2f(window.left(), window.bottom());
                glVertex2f(window.left(), window.bottom());
                
                glEnd();
                
                glDisable(GL_TEXTURE_RECTANGLE_ARB);
                glEnable(GL_BLEND);
            }
        }
    };
}

#pragma mark
#pragma mark Private members

@interface CropperGLView ()
{
    SyphonClientGLV _glv;
}

- (void)drawView;

@end

#pragma mark
#pragma mark DisplayLink Callbacks

static CVReturn DisplayLinkOutputCallback(CVDisplayLinkRef displayLink,
                                          const CVTimeStamp *now,
                                          const CVTimeStamp *outputTime,
                                          CVOptionFlags flagsIn,
                                          CVOptionFlags *flagsOut,
                                          void *displayLinkContext)
{
    CropperGLView *view = (__bridge CropperGLView *)displayLinkContext;
    [view drawView];
	return kCVReturnSuccess;
}

#pragma mark
#pragma mark Class implementation

@implementation CropperGLView

#pragma mark Constructor and destructor

- (void)awakeFromNib
{
    NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAPixelBuffer,
        NSOpenGLPFAColorSize, 32,
        0
    };
    
    self.pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    self.openGLContext = [[NSOpenGLContext alloc] initWithFormat:self.pixelFormat shareContext:nil];

    CGSize size = self.frame.size;
    _glv.extent(size.width, size.height);
    _glv.broadcastEvent(glv::Event::WindowCreate);
}

- (void)dealloc
{
    CVDisplayLinkStop(_displayLink);
    CVDisplayLinkRelease(_displayLink);
}

- (GLVREF)glv
{
    return MakeReference(_glv);
}

#pragma mark NSOpenGLView methods

- (void)prepareOpenGL
{
    [super prepareOpenGL];
    
    // Maximize framerate.
    GLint interval = 1;
    [self.openGLContext setValues:&interval forParameter:NSOpenGLCPSwapInterval];
    
    // Initialize DisplayLink.
    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
    CVDisplayLinkSetOutputCallback(_displayLink, DisplayLinkOutputCallback, (__bridge void *)(self));
    
    CGLContextObj cglCtx = (CGLContextObj)(self.openGLContext.CGLContextObj);
    CGLPixelFormatObj cglPF = (CGLPixelFormatObj)(self.pixelFormat.CGLPixelFormatObj);
    CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(_displayLink, cglCtx, cglPF);
    
    CVDisplayLinkStart(_displayLink);
    
    // Add an observer for closing the window.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowWillClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:self.window];
}

#pragma mark NSWindow methods

- (void)windowWillClose:(NSNotification *)notification
{
    // DisplayLink need to be stopped manually.
    CVDisplayLinkStop(_displayLink);
}

- (void)drawRect:(NSRect)dirtyRect
{
    [self drawView];
}

#pragma mark Private methods

- (void)drawView
{
    CGLContextObj cglCtx = (CGLContextObj)(self.openGLContext.CGLContextObj);
    
    // Lock DisplayLink.
    CGLLockContext(cglCtx);
    
    // Draw with GLV.
    CGSize size = self.frame.size;
    [self.openGLContext makeCurrentContext];
    
    if (self.syphonClient)
    {
        _glv.image = [self.syphonClient newFrameImageForContext:cglCtx];
    }
    
    _glv.drawGLV(size.width, size.height, 1.0 / 60);
    _glv.image = nil;
    
    // Flush and unlock DisplayLink.
    CGLFlushDrawable(cglCtx);
    CGLUnlockContext(cglCtx);
}

@end
