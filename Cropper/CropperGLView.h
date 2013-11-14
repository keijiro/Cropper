#import <Cocoa/Cocoa.h>

@class SyphonClient;

@interface CropperGLView : NSOpenGLView
{
    CVDisplayLinkRef _displayLink;
    float _margins[4];
}

@property (strong) SyphonClient *syphonClient;

@end
