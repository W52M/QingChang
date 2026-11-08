#include "RealtimeAudio.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <math.h>
#define CAP 262144
struct QCRing { float data[CAP]; _Atomic uint64_t written; _Atomic float level; double read, step, inputRate; int primed; };
QCRing *qc_create(void) { return calloc(1,sizeof(QCRing)); }
void qc_destroy(QCRing *r) { free(r); }
void qc_reset(QCRing *r,double inputRate,double outputRate) { atomic_store(&r->written,0); atomic_store(&r->level,0);r->read=0;r->step=inputRate/outputRate;r->inputRate=inputRate;r->primed=0; }
void qc_write(QCRing *r,const float *data,uint32_t count) { uint64_t w=atomic_load_explicit(&r->written,memory_order_relaxed);float sum=0;for(uint32_t i=0;i<count;i++){float v=isfinite(data[i])?data[i]:0;r->data[(w+i)%CAP]=v;sum+=v*v;}atomic_store_explicit(&r->written,w+count,memory_order_release);atomic_store(&r->level,sqrtf(sum/fmaxf(1,count))); }
void qc_render(QCRing *r,float *data,uint32_t count) { uint64_t w=atomic_load_explicit(&r->written,memory_order_acquire);double need=count*r->step+2;
 if(!r->primed){if(w<need*2){for(uint32_t i=0;i<count;i++)data[i]=0;return;}r->read=w-need*2;r->primed=1;}
 // Keep only a few hardware blocks queued; never accumulate seconds of echo.
 if(w-r->read>need*6+32)r->read=w-need*2;
 double error=(double)w-r->read-need*2;double drift=fmax(-0.002,fmin(0.002,error/2000000));double step=r->step*(1+drift);
 for(uint32_t i=0;i<count;i++){uint64_t a=(uint64_t)r->read;if(a+1>=w){data[i]=0;continue;}double f=r->read-a;data[i]=fmaxf(-0.75f,fminf(0.75f,(float)(r->data[a%CAP]*(1-f)+r->data[(a+1)%CAP]*f)));r->read+=step;}
}
float qc_level(QCRing *r){return atomic_load(&r->level);}
float qc_pitch(QCRing *r){uint64_t w=atomic_load_explicit(&r->written,memory_order_acquire);if(w<4096||qc_level(r)<0.006)return 0;float x[1024],mean=0;for(int i=0;i<1024;i++){x[i]=r->data[(w-4096+i*4)%CAP];mean+=x[i];}mean/=1024;for(int i=0;i<1024;i++)x[i]-=mean;
 double rate=r->inputRate/4;int lo=(int)(rate/900),hi=(int)(rate/70);float corr[256]={0},best=0;int bestLag=0;if(hi>254)hi=254;if(lo<2)lo=2;
 for(int lag=lo;lag<=hi;lag++){double ab=0,aa=0,bb=0;for(int i=0;i<1024-lag;i++){ab+=x[i]*x[i+lag];aa+=x[i]*x[i];bb+=x[i+lag]*x[i+lag];}corr[lag]=(float)(ab/sqrt(aa*bb+1e-15));if(corr[lag]>best){best=corr[lag];bestLag=lag;}}
 if(best<.72)return 0;for(int lag=lo+1;lag<hi;lag++){if(corr[lag]>.82&&corr[lag]>best*.92&&corr[lag]>=corr[lag-1]&&corr[lag]>=corr[lag+1]){bestLag=lag;break;}}return bestLag>0?(float)(rate/bestLag):0;}
