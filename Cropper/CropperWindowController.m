#import "CropperWindowController.h"
#import "CropperGLView.h"
#import <Syphon/Syphon.h>

@interface CropperWindowController ()

@end

@implementation CropperWindowController

- (void)keyDown:(NSEvent *)theEvent
{
//    unichar c = [theEvent.characters characterAtIndex:0];
}

- (void)updateServerList:(id)sender
{
    NSArray *servers = [[SyphonServerDirectory sharedDirectory] servers];
    if (servers.count > 0) [self startClient:[servers objectAtIndex:0]];
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateServerList:) userInfo:self repeats:YES];
}

- (void)startClient:(NSDictionary *)description
{
    _syphonClient = [[SyphonClient alloc] initWithServerDescription:description options:nil newFrameHandler:nil];
    _glView.syphonClient = _syphonClient;
}

@end
