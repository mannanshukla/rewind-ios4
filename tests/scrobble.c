#include <assert.h>
#include "../src/ScrobbleMath.h"
int main(void){
assert(RWScrobbleThreshold(30)<0);assert(RWScrobbleThreshold(NAN)<0);
assert(RWScrobbleThreshold(31)==15.5);assert(RWScrobbleThreshold(200)==100);assert(RWScrobbleThreshold(480)==240);assert(RWScrobbleThreshold(900)==240);
assert(RWScrobbleCredit(10,20,10)==10);
assert(RWScrobbleCredit(10,10,30)==0);   /* paused */
assert(RWScrobbleCredit(60,20,5)==0);    /* rewound */
assert(RWScrobbleCredit(10,100,5)==0);   /* seeked ahead */
assert(RWScrobbleCredit(10,13,1.5)==3);  /* timer jitter within 2 s */
assert(RWScrobbleCredit(0,300,310)==300);/* suspended while the same track kept playing */
assert(RWScrobbleRestarted(200,1));assert(!RWScrobbleRestarted(8,1));assert(!RWScrobbleRestarted(200,30));assert(!RWScrobbleRestarted(NAN,1));
return 0;}
