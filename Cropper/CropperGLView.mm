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
#pragma mark Class implementation

@implementation CropperGLView

#pragma mark Constructor and destructor

- (void)awakeFromNib
{
    NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAColorSize, 32,
        0
    };
    
    self.pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    self.openGLContext = [[NSOpenGLContext alloc] initWithFormat:self.pixelFormat shareContext:nil];

    CGSize size = self.frame.size;
    _glv.extent(size.width, size.height);
    _glv.broadcastEvent(glv::Event::WindowCreate);
    
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateServerList:) userInfo:self repeats:YES];
    [NSTimer scheduledTimerWithTimeInterval:1.0f / 60 target:self selector:@selector(updateFrame:) userInfo:self repeats:YES];
}

- (void)updateFrame:(id)sender
{
    self.needsDisplay = YES;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

#pragma mark Server communication

- (void)updateServerList:(id)sender
{
    // Releases the client if it got invalid.
    if (_syphonClient && !_syphonClient.isValid) _syphonClient = nil;
    
    // Retrives the server list.
    NSArray *servers = [[SyphonServerDirectory sharedDirectory] servers];

    // Is there any server?
    if (servers.count > 0)
    {
        // Uses the first server.
        NSDictionary *serverDescription = [servers objectAtIndex:0];
        
        // Releases the old client if it's different from this one.
        if (![serverDescription isEqualToDictionary:_syphonClient.serverDescription]) _syphonClient = nil;
        
        // Creates a client if there is no server.
        if (_syphonClient == nil) [self startClient:serverDescription];
    }
    else
    {
        // No server: it should be released.
        if (_syphonClient) _syphonClient = nil;
    }
}

- (void)startClient:(NSDictionary *)description
{
    _syphonClient = [[SyphonClient alloc] initWithServerDescription:description options:nil newFrameHandler:^(SyphonClient*){
        self.needsDisplay = YES;
    }];
}

#pragma mark NSOpenGLView methods

- (void)prepareOpenGL
{
    [super prepareOpenGL];

    // Enable VSync.
    GLint interval = 1;
    [self.openGLContext setValues:&interval forParameter:NSOpenGLCPSwapInterval];
}

#pragma mark NSWindow methods

- (void)update
{
    [super update];
    CGSize size = self.frame.size;
    _glv.extent(size.width, size.height);
    _glv.broadcastEvent(glv::Event::WindowResize);
}

- (void)reshape
{
    [super reshape];
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
    
    // Draw with GLV.
    CGSize size = self.frame.size;
    [self.openGLContext makeCurrentContext];
    
    SyphonImage *image = nil;
    
    if (_syphonClient)
    {
        image = [_syphonClient newFrameImageForContext:cglCtx];
    }

    if (image)
    {
        _glv.mImageView.imageTextureName = image.textureName;
    }
    
    _glv.drawGLV(size.width, size.height, 1.0 / 60);
    
    _glv.mImageView.imageTextureName = -1;
    image = nil;
    
    CGLFlushDrawable(cglCtx);
}

@end
