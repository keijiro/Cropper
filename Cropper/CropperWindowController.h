#import <Cocoa/Cocoa.h>
#import "GLVX.h"

@class SyphonClient;
@class CropperGLView;

@interface CropperWindowController : NSWindowController <NSWindowDelegate>
{
    SyphonClient *_syphonClient;
    IBOutlet CropperGLView *_cropperGLView;
}

@end
