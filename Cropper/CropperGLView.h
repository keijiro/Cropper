#import <Cocoa/Cocoa.h>
#import "GLVX.h"

@class SyphonClient;

@interface CropperGLView : NSOpenGLView
{
    CVDisplayLinkRef _displayLink;
}

@property (readonly) GLVREF glv;
@property (strong) SyphonClient *syphonClient;

@end
