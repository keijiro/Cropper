#import <Cocoa/Cocoa.h>

@interface CropperGLView : NSOpenGLView
{
    CVDisplayLinkRef _displayLink;
}

@end
