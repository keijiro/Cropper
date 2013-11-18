#import "CropperGLView.h"
#import "glv.h"
#import "Syphon/Syphon.h"

#pragma mark
#pragma mark GLV interface

namespace
{
    struct SyphonImageView : public glv::View
    {
        SyphonImage *image;
        glv::Rect imageRect;
        
        SyphonImageView()
        :   glv::View(glv::Rect(600, 400)),
            image(nil),
            imageRect(0, 0, 600, 400)
        {
            using namespace glv;

            colors().set(StyleColor::WhiteOnBlack);
            disable(DrawBack);
        }
        
        void reset()
        {
            pos(0, 0);
            extent(600, 400);
            imageRect.pos(0, 0);
            imageRect.extent(600, 400);
        }
        
        virtual void onDraw(glv::GLV& g)
        {
            if (!image) return;
            
            glDisable(GL_BLEND);
            glEnable(GL_TEXTURE_RECTANGLE_ARB);
            glBindTexture(GL_TEXTURE_RECTANGLE_ARB, image.textureName);
            
            glBegin(GL_QUADS);

            glColor3f(1, 1, 1);
            
            glv::Rect& ir = imageRect;
            glTexCoord2f(ir.left(), ir.top());
            glVertex2f(0, 0);
            
            glTexCoord2f(ir.right(), ir.top());
            glVertex2f(width(), 0);
            
            glTexCoord2f(ir.right(), ir.bottom());
            glVertex2f(width(), height());
            
            glTexCoord2f(ir.left(), ir.bottom());
            glVertex2f(0, height());
            
            glEnd();
        
            glDisable(GL_TEXTURE_RECTANGLE_ARB);
            glEnable(GL_BLEND);
        }
        
        virtual bool onEvent(glv::Event::t e, glv::GLV& g)
        {
            using namespace glv;
            
            if (e == Event::MouseDrag)
            {
                const float border = 32;
                
                bool shift = g.keyboard().shift();
                float dx = g.mouse().dx();
                float dy = g.mouse().dy();
                float mx = g.mouse().xRel() - dx;	// subtract diff because position already updated
                float my = g.mouse().yRel() - dy;
                bool resizing = false;
                
                if (mx < border)
                {
                    resizeLeftTo(left() + dx);
                    if (!shift) imageRect.resizeLeftTo(imageRect.left() + dx);
                    resizing = true;
                }
                else if (width() - border < mx && mx < width())
                {
                    resizeRightTo(right() + dx);
                    if (!shift) imageRect.resizeRightTo(imageRect.right() + dx);
                    resizing = true;
                }
                
                if (my < border)
                {
                    resizeTopTo(top() + dy);
                    if (!shift) imageRect.resizeTopTo(imageRect.top() + dy);
                    resizing = true;
                }
                else if (height() - border < my && my < height())
                {
                    resizeBottomTo(bottom() + dy);
                    if (!shift) imageRect.resizeBottomTo(imageRect.bottom() + dy);
                    resizing = true;
                }
                
                if (resizing)
                {
                    rectifyGeometry();
                }
                else
                {
                    move(dx, dy);
                    if (!shift) imageRect.posAdd(dx, dy);
                }
            }
            
            return true;
        }
    };
    
    struct SyphonClientGLV : public glv::GLV
    {
        SyphonImageView mImageView;
        glv::Label mInstruction;
        bool mShowUI;
        
        static const char* instruction()
        {
            return
                "MOUSE DRAG : MOVE/RESIZE CROPPING WINDOW\n"
                "SHIFT DRAG : MOVE/RESIZE CONTENT OF WINDOW\n"
                "R          : RESET\n"
                "SPACE      : SHOW/HIDE UI";
        }
        
        SyphonClientGLV()
        :   GLV(600, 300),
            mInstruction(instruction()),
            mShowUI(true)
        {
            using namespace glv;
            
            colors().set(StyleColor::WhiteOnBlack);
            
            mInstruction.anchor(Place::BL).pos(Place::BL);
            
            *this << mImageView << mInstruction;
        }
        
        virtual bool onEvent(glv::Event::t e, glv::GLV& g)
        {
            using namespace glv;
            
            if (e == Event::KeyDown)
            {
                int key = g.keyboard().key();
                if (key == ' ')
                {
                    mShowUI = !mShowUI;
                    
                    if (mShowUI)
                    {
                        mImageView.colors().border.a = 1;
                        mInstruction.colors().text.a = 1;
                    }
                    else
                    {
                        mImageView.colors().border.a = 0;
                        mInstruction.colors().text.a = 0;
                    }
                }
                else if (key == 'r')
                {
                    mImageView.reset();
                }
            }
            
            return true;
        }
    };
}

#pragma mark
#pragma mark Private members

@interface CropperGLView ()
{
    SyphonClient *_syphonClient;
    SyphonClientGLV _glv;
}

- (void)updateServerList:(id)sender;
- (void)startClient:(NSDictionary *)description;
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
    
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateServerList:) userInfo:self repeats:YES];
}

- (void)dealloc
{
    CVDisplayLinkStop(_displayLink);
    CVDisplayLinkRelease(_displayLink);
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

#pragma mark Server communication

- (void)updateServerList:(id)sender
{
    NSArray *servers = [[SyphonServerDirectory sharedDirectory] servers];
    if (servers.count > 0) [self startClient:[servers objectAtIndex:0]];
}

- (void)startClient:(NSDictionary *)description
{
    _syphonClient = [[SyphonClient alloc] initWithServerDescription:description options:nil newFrameHandler:nil];
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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidResize:)
                                                 name:NSWindowDidResizeNotification
                                               object:self.window];
}

#pragma mark NSWindow methods

- (void)windowWillClose:(NSNotification *)notification
{
    // DisplayLink need to be stopped manually.
    CVDisplayLinkStop(_displayLink);
}

- (void)windowDidResize:(NSNotification *)notification
{
    CGSize size = self.frame.size;
    _glv.extent(size.width, size.height);
    _glv.broadcastEvent(glv::Event::WindowResize);
}

- (void)drawRect:(NSRect)dirtyRect
{
    [self drawView];
}

#pragma mark Key events

- (void)applyModifierKey:(NSEvent *)theEvent
{
    NSUInteger mod = theEvent.modifierFlags;
    _glv.setKeyModifiers(mod & NSShiftKeyMask,
                         mod & NSAlternateKeyMask,
                         mod & NSControlKeyMask,
                         mod & NSAlphaShiftKeyMask,
                         mod & NSCommandKeyMask);
}

- (void)processKeyEvent:(NSEvent *)theEvent
{
    [self applyModifierKey:theEvent];
    
    unsigned int key = [theEvent.charactersIgnoringModifiers characterAtIndex:0];
    if (theEvent.type == NSKeyDown)
    {
        _glv.setKeyDown(key);
    }
    else if (theEvent.type == NSKeyUp)
    {
        _glv.setKeyUp(key);
    }
    
    _glv.propagateEvent();
}

- (void)keyDown:(NSEvent *)theEvent
{
    [self processKeyEvent:theEvent];
}

- (void)keyUp:(NSEvent *)theEvent
{
    [self processKeyEvent:theEvent];
}

#pragma mark Mouse events

- (void)mouseDown:(NSEvent *)theEvent
{
    [self processMouseEvent:theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    [self processMouseEvent:theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    [self processMouseEvent:theEvent];
}

- (void)processMouseEvent:(NSEvent *)theEvent
{
    [self applyModifierKey:theEvent];
    
    // Flip vertically.
    NSPoint point = theEvent.locationInWindow;
    CGSize size = [self.window.contentView frame].size;
    point.y = size.height - point.y;
    
    glv::space_t relx = point.x;
    glv::space_t rely = point.y;
    
    if (theEvent.type == NSLeftMouseDown)
    {
        _glv.setMouseDown(relx, rely, glv::Mouse::Left, 0);
    }
    else if (theEvent.type == NSLeftMouseDragged)
    {
        _glv.setMouseMotion(relx, rely, glv::Event::MouseDrag);
    }
    else if (theEvent.type == NSLeftMouseUp)
    {
        _glv.setMouseUp(relx, rely, glv::Mouse::Left, 0);
    }
    
    _glv.setMousePos(point.x, point.y, relx, rely);
    _glv.propagateEvent();
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
        _glv.mImageView.image = [self.syphonClient newFrameImageForContext:cglCtx];
    }
    
    _glv.drawGLV(size.width, size.height, 1.0 / 60);
    _glv.mImageView.image = nil;
    
    // Flush and unlock DisplayLink.
    CGLFlushDrawable(cglCtx);
    CGLUnlockContext(cglCtx);
}

@end
