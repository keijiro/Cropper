#import "CropperAppDelegate.h"

@interface CropperAppDelegate ()
{
    NSMutableArray *_windowControllers;
}
@end

@implementation CropperAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _windowControllers = [NSMutableArray array];
    [self newWindow:self];
}

- (IBAction)newWindow:(id)sender {
    NSWindowController *controller = [[NSWindowController alloc] initWithWindowNibName:@"CropperWindow"];
    [controller showWindow:controller.window];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowWillClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:controller.window];
    
    [_windowControllers addObject:controller];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [_windowControllers removeObject:[notification.object windowController]];
}

@end
