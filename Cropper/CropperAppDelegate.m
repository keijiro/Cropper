#import "CropperAppDelegate.h"
#import "CropperWindowController.h"

@implementation CropperAppDelegate

- (IBAction)newWindow:(id)sender {
    CropperWindowController *controller = [[CropperWindowController alloc] initWithWindowNibName:@"CropperWindow"];
    [controller showWindow:controller.window];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    CropperWindowController *controller = [[CropperWindowController alloc] initWithWindowNibName:@"CropperWindow"];
    [controller showWindow:controller.window];
}

@end
