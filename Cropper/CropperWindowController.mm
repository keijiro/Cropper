#import "CropperWindowController.h"
#import "CropperGLView.h"
#import "glv.h"
#import <Syphon/Syphon.h>

#pragma mark Private members

@interface CropperWindowController ()

- (void)updateServerList:(id)sender;
- (void)startClient:(NSDictionary *)description;

- (void)applyModifierKey:(NSEvent *)theEvent;
- (void)processKeyEvent:(NSEvent *)theEvent;
- (void)processMouseEvent:(NSEvent *)theEvent;

@end

#pragma mark
#pragma mark Class implementation

@implementation CropperWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateServerList:) userInfo:self repeats:YES];
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
    _cropperGLView.syphonClient = _syphonClient;
}

#pragma mark Window handling events

- (void)windowDidResize:(NSNotification *)notification
{
    glv::GLV& target = glv::Dereference(_cropperGLView.glv);
    CGSize size = [self.window.contentView frame].size;
    target.extent(size.width, size.height);
    target.broadcastEvent(glv::Event::WindowResize);
}

#pragma mark Key events

- (void)applyModifierKey:(NSEvent *)theEvent
{
    glv::GLV& target = glv::Dereference(_cropperGLView.glv);
    NSUInteger mod = theEvent.modifierFlags;
    target.setKeyModifiers(mod & NSShiftKeyMask,
                           mod & NSAlternateKeyMask,
                           mod & NSControlKeyMask,
                           mod & NSAlphaShiftKeyMask,
                           mod & NSCommandKeyMask);
}

- (void)processKeyEvent:(NSEvent *)theEvent
{
    glv::GLV& target = glv::Dereference(_cropperGLView.glv);
    
    [self applyModifierKey:theEvent];
    
    unsigned int key = [theEvent.charactersIgnoringModifiers characterAtIndex:0];
    if (theEvent.type == NSKeyDown)
    {
        target.setKeyDown(key);
    }
    else if (theEvent.type == NSKeyUp)
    {
        target.setKeyUp(key);
    }
    
    target.propagateEvent();
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
    glv::GLV& target = glv::Dereference(_cropperGLView.glv);
    
    [self applyModifierKey:theEvent];
    
    // Flip vertically.
    NSPoint point = theEvent.locationInWindow;
    CGSize size = [self.window.contentView frame].size;
    point.y = size.height - point.y;
    
    glv::space_t relx = point.x;
    glv::space_t rely = point.y;
    
    if (theEvent.type == NSLeftMouseDown)
    {
        target.setMouseDown(relx, rely, glv::Mouse::Left, 0);
    }
    else if (theEvent.type == NSLeftMouseDragged)
    {
        target.setMouseMotion(relx, rely, glv::Event::MouseDrag);
    }
    else if (theEvent.type == NSLeftMouseUp)
    {
        target.setMouseUp(relx, rely, glv::Mouse::Left, 0);
    }
    
    target.setMousePos(point.x, point.y, relx, rely);
    target.propagateEvent();
}

@end
