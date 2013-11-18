#import "CropperGLView.h"
#import "Syphon/Syphon.h"
#import "SyphonClientGLV.h"

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
    
    SyphonImage *image = nil;
    
    if (self.syphonClient)
    {
        image = [self.syphonClient newFrameImageForContext:cglCtx];
    }

    if (image)
    {
        _glv.mImageView.imageTextureName = image.textureName;
    }
    
    _glv.drawGLV(size.width, size.height, 1.0 / 60);
    
    _glv.mImageView.imageTextureName = -1;
    image = nil;
    
    // Flush and unlock DisplayLink.
    CGLFlushDrawable(cglCtx);
    CGLUnlockContext(cglCtx);
}

@end
