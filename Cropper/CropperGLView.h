#import <Cocoa/Cocoa.h>

@class SyphonClient;

@interface CropperGLView : NSOpenGLView
{
    CVDisplayLinkRef _displayLink;
}

@property (strong) SyphonClient *syphonClient;

@end
