#ifndef RW_SCROLL_MATH_H
#define RW_SCROLL_MATH_H
#include <math.h>
#define RW_SCROLL_PAUSE 1.5
#define RW_SCROLL_GAP 28.0
// Whole-pixel marquee offset. Monochrome LCDs step one logical pixel per tick.
static inline double RWScrollOffsetAt(double width,double viewport,double elapsed,double speed) {
    if(width<=viewport||speed<=0)return 0;
    double distance=width+RW_SCROLL_GAP;
    double phase=fmod(fmax(0,elapsed),RW_SCROLL_PAUSE+distance/speed);
    return phase<=RW_SCROLL_PAUSE?0:floor((phase-RW_SCROLL_PAUSE)*speed);
}
static inline double RWScrollOffset(double width,double viewport,double elapsed) {return RWScrollOffsetAt(width,viewport,elapsed,24.0);}
#endif
