// Last.fm scrobble rules, kept free of UIKit so tests/scrobble.c can check them.
#ifndef RW_SCROBBLE_MATH_H
#define RW_SCROBBLE_MATH_H
#include <math.h>

// Seconds of listening a track needs before it counts: half its length or four
// minutes, whichever comes first. Tracks of 30 seconds or less never count (-1).
static inline double RWScrobbleThreshold(double duration){
    if(!isfinite(duration)||duration<=30)return -1;
    return fmin(duration/2,240);
}

// Listening credited between two observations of the same track. Only forward
// movement no larger than the wall-clock time that passed counts, so pausing,
// rewinding and seeking ahead earn nothing.
static inline double RWScrobbleCredit(double lastPosition,double position,double wallElapsed){
    if(!isfinite(lastPosition)||!isfinite(position)||!isfinite(wallElapsed))return 0;
    double moved=position-lastPosition;
    if(moved<=0||wallElapsed<=0)return 0;
    if(moved>wallElapsed+2)return 0;
    return moved;
}

// The same track jumped back to near its start after it had played a while:
// Repeat One, or Previous pressed after the first few seconds. That begins a new play.
static inline int RWScrobbleRestarted(double lastPosition,double position){
    return isfinite(lastPosition)&&isfinite(position)&&lastPosition>=10&&position<5&&position<lastPosition;
}
#endif
