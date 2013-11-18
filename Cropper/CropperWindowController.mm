#import "CropperWindowController.h"
#import "CropperGLView.h"
#import <Syphon/Syphon.h>

#pragma mark Private members

@interface CropperWindowController ()

- (void)updateServerList:(id)sender;
- (void)startClient:(NSDictionary *)description;

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

@end
