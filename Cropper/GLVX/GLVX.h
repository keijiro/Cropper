#ifndef GLVX_GLVX_h
#define GLVX_GLVX_h

struct GLVREFStruct {};

typedef struct GLVREFStruct *GLVREF;

#ifdef __cplusplus

namespace glv
{
    class GLV;
    
    inline GLVREF MakeReference(glv::GLV &glv)
    {
        return reinterpret_cast<GLVREF>(&glv);
    }
    
    inline glv::GLV& Dereference(GLVREF ref)
    {
        return *reinterpret_cast<glv::GLV*>(ref);
    }
}

#endif

#endif
