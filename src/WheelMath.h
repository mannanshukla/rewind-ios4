#ifndef WHEEL_MATH_H
#define WHEEL_MATH_H
#include <math.h>
static inline double RWAngleDelta(double now,double before) {double d=now-before;while(d>M_PI)d-=2*M_PI;while(d< -M_PI)d+=2*M_PI;return d;}
static inline int RWClampSelection(int current,int delta,int count) {if(count<=0)return 0;long next=(long)current+delta;return next<0?0:next>=count?count-1:(int)next;}
#endif
