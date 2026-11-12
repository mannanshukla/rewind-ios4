#include <assert.h>
#include "../src/WheelMath.h"
int main(void){assert(fabs(RWAngleDelta(-3.1,3.1)-.083185307)<.00001);assert(fabs(RWAngleDelta(3.1,-3.1)+.083185307)<.00001);assert(RWClampSelection(0,-3,10)==0);assert(RWClampSelection(8,30,10)==9);assert(RWClampSelection(2,1,10)==3);assert(RWClampSelection(0,4,0)==0);double fine=0,coarse=0;int a=0,b=0;
for(int i=0;i<100;i++)a+=RWConsumeWheelSteps(&fine,2*M_PI/100);
for(int i=0;i<10;i++)b+=RWConsumeWheelSteps(&coarse,2*M_PI/10);
assert(a==19&&b==19);assert(fabs(fine-coarse)<1e-10);
double jitter=0;for(int i=0;i<100;i++){assert(RWConsumeWheelSteps(&jitter,.05)==0);assert(RWConsumeWheelSteps(&jitter,-.05)==0);}
assert(RWConsumeWheelSteps(&jitter,-.33)==-1);
return 0;}
