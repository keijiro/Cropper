#ifndef Cropper_SyphonClientGLV_h
#define Cropper_SyphonClientGLV_h

#import "glv.h"

struct SyphonImageView : public glv::View
{
    GLint imageTextureName;
    glv::Rect imageRect;
    
    SyphonImageView()
    :   glv::View(glv::Rect(600, 400)),
    imageTextureName(-1),
    imageRect(0, 0, 600, 400)
    {
        using namespace glv;
        
        colors().set(StyleColor::WhiteOnBlack);
        disable(DrawBack);
    }
    
    void reset()
    {
        pos(0, 0);
        extent(600, 400);
        imageRect.pos(0, 0);
        imageRect.extent(600, 400);
    }
    
    virtual void onDraw(glv::GLV& g)
    {
        if (imageTextureName < 0) return;
        
        glDisable(GL_BLEND);
        glEnable(GL_TEXTURE_RECTANGLE_ARB);
        glBindTexture(GL_TEXTURE_RECTANGLE_ARB, imageTextureName);
        
        glBegin(GL_QUADS);
        
        glColor3f(1, 1, 1);
        
        glv::Rect& ir = imageRect;
        glTexCoord2f(ir.left(), ir.bottom());
        glVertex2f(0, 0);
        
        glTexCoord2f(ir.right(), ir.bottom());
        glVertex2f(width(), 0);
        
        glTexCoord2f(ir.right(), ir.top());
        glVertex2f(width(), height());
        
        glTexCoord2f(ir.left(), ir.top());
        glVertex2f(0, height());
        
        glEnd();
        
        glDisable(GL_TEXTURE_RECTANGLE_ARB);
        glEnable(GL_BLEND);
    }
    
    virtual bool onEvent(glv::Event::t e, glv::GLV& g)
    {
        using namespace glv;
        
        if (e == Event::MouseDrag)
        {
            const float border = 32;
            
            bool shift = g.keyboard().shift();
            float dx = g.mouse().dx();
            float dy = g.mouse().dy();
            float mx = g.mouse().xRel() - dx;	// subtract diff because position already updated
            float my = g.mouse().yRel() - dy;
            bool resizing = false;
            
            if (mx < border)
            {
                resizeLeftTo(left() + dx);
                if (!shift) imageRect.resizeLeftTo(imageRect.left() + dx);
                resizing = true;
            }
            else if (width() - border < mx && mx < width())
            {
                resizeRightTo(right() + dx);
                if (!shift) imageRect.resizeRightTo(imageRect.right() + dx);
                resizing = true;
            }
            
            if (my < border)
            {
                resizeTopTo(top() + dy);
                if (!shift) imageRect.resizeTopTo(imageRect.top() + dy);
                resizing = true;
            }
            else if (height() - border < my && my < height())
            {
                resizeBottomTo(bottom() + dy);
                if (!shift) imageRect.resizeBottomTo(imageRect.bottom() + dy);
                resizing = true;
            }
            
            if (resizing)
            {
                rectifyGeometry();
            }
            else
            {
                move(dx, dy);
                if (!shift) imageRect.posAdd(dx, dy);
            }
        }
        
        return true;
    }
};

struct SyphonClientGLV : public glv::GLV
{
    SyphonImageView mImageView;
    glv::Label mInstruction;
    bool mShowUI;
    
    static const char* instruction()
    {
        return
        "MOUSE DRAG : MOVE/RESIZE CROPPING WINDOW\n"
        "SHIFT DRAG : MOVE/RESIZE CONTENT OF WINDOW\n"
        "R          : RESET\n"
        "SPACE      : SHOW/HIDE UI\n"
        "1 - 9      : LOAD A PRESET\n"
        "CMD + NUM  : SAVE A PRESET";
    }
    
    SyphonClientGLV()
    :   GLV(600, 300),
    mInstruction(instruction()),
    mShowUI(true)
    {
        using namespace glv;
        
        colors().set(StyleColor::WhiteOnBlack);
        
        mInstruction.anchor(Place::BL).pos(Place::BL);
        
        *this << mImageView << mInstruction;
    }
    
    virtual bool onEvent(glv::Event::t e, glv::GLV& g)
    {
        using namespace glv;
        
        if (e == Event::KeyDown)
        {
            int key = g.keyboard().key();
            if (key == ' ')
            {
                mShowUI = !mShowUI;
                
                if (mShowUI)
                {
                    mImageView.colors().border.a = 1;
                    mInstruction.colors().text.a = 1;
                }
                else
                {
                    mImageView.colors().border.a = 0;
                    mInstruction.colors().text.a = 0;
                }
            }
            else if (key == 'r')
            {
                mImageView.reset();
            }
            else if (key >= '1' && key <= '9')
            {
                NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
                NSString *configName = [NSString stringWithFormat:@"rect%c", key];
                if (g.keyboard().meta())
                {
                    NSRect rect = CGRectMake(mImageView.left(), mImageView.top(), mImageView.width(), mImageView.height());
                    [ud setObject:NSStringFromRect(rect) forKey:configName];
                    [ud synchronize];
                }
                else
                {
                    NSRect rect = NSRectFromString([ud valueForKey:configName]);
                    mImageView.pos(rect.origin.x, rect.origin.y);
                    mImageView.width(rect.size.width);
                    mImageView.height(rect.size.height);
                }
            }
        }
        
        return true;
    }
};

#endif
