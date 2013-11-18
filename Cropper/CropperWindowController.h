#import <Cocoa/Cocoa.h>

@class SyphonClient;
@class CropperGLView;

@interface CropperWindowController : NSWindowController
{
    SyphonClient *_syphonClient;
    IBOutlet CropperGLView *_cropperGLView;
}

@end
