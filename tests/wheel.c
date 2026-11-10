#include <assert.h>
#include "../src/WheelMath.h"
int main(void){assert(fabs(RWAngleDelta(-3.1,3.1)-.083185307)<.00001);assert(fabs(RWAngleDelta(3.1,-3.1)+.083185307)<.00001);assert(RWClampSelection(0,-3,10)==0);assert(RWClampSelection(8,30,10)==9);assert(RWClampSelection(2,1,10)==3);assert(RWClampSelection(0,4,0)==0);return 0;}
