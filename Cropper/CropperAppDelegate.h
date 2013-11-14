#import <Cocoa/Cocoa.h>

@class SyphonClient;
@class CropperGLView;

@interface CropperAppDelegate : NSObject <NSApplicationDelegate>
{
    SyphonClient *_syphonClient;
    IBOutlet CropperGLView *_glView;
}

@property (assign) IBOutlet NSWindow *window;

@end
