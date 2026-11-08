#include "RealtimeAudio.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
static void test(double rate) {
 QCRing *r=qc_create(); qc_reset(r,rate,48000);
 float in[256],out[128];double phase=0, inputCount=0; double energy=0;int crossings=0,n=0;float prior=0;
 for(int block=0;block<750;block++){
  int count=(int)floor((block+1)*128*rate/48000)-inputCount;inputCount+=count;
  for(int j=0;j<count;j++){in[j]=0.2*sin(phase);phase+=2*M_PI*440/rate;}
  qc_write(r,in,count);qc_render(r,out,128);
  if(block>20)for(int j=0;j<128;j++){assert(isfinite(out[j]));assert(fabs(out[j])<=0.201);energy+=out[j]*out[j];if(prior<=0 && out[j]>0)crossings++;prior=out[j];n++;}
 }
 double freq=crossings*48000.0/n,rms=sqrt(energy/n),pitch=qc_pitch(r);
 assert(fabs(freq-440)<3);assert(rms>0.13 && rms<0.15);assert(fabs(pitch-440)<20);
 qc_reset(r,rate,48000);qc_render(r,out,128);for(int j=0;j<128;j++)assert(out[j]==0);
 qc_destroy(r);printf("%.0f -> 48000 Hz: waveform %.2f Hz, RMS %.3f, pitch %.2f Hz; reset silence passed\n",rate,freq,rms,pitch);
}
int main(){test(48000);test(44100);
 QCRing *r=qc_create();qc_reset(r,48000,48000);float loud[1024],out[128];for(int i=0;i<1024;i++)loud[i]=i%2 ? 10:-10;qc_write(r,loud,1024);qc_render(r,out,128);for(int i=0;i<128;i++)assert(isfinite(out[i]) && fabs(out[i])<=0.75001);qc_destroy(r);puts("Monitor sample peak cap passed; this is not acoustic echo cancellation");return 0;}
