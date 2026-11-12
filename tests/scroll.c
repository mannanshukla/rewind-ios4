#include <assert.h>
#include "../src/ScrollMath.h"
int main(void) {
 assert(RWScrollOffset(80,100,100)==0);
 assert(RWScrollOffset(100,100,100)==0);
 assert(RWScrollOffset(200,100,-1)==0);
 assert(RWScrollOffset(200,100,1.4)==0);
 assert(RWScrollOffset(200,100,2.5)==24);
 assert(RWScrollOffset(200,100,11)==0);
 assert(RWScrollOffset(200,100,12)==0);
 // Monochrome speed: one whole pixel per 1/20 s tick, uniform steps.
 for(int i=0;i<60;i++)assert(RWScrollOffsetAt(300,100,1.5+i/20.0+1e-9,20)==i);
 assert(RWScrollOffsetAt(300,100,5,0)==0);
 return 0;
}
