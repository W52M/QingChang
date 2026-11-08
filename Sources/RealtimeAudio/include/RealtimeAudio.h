#ifndef REALTIME_AUDIO_H
#define REALTIME_AUDIO_H
#include <stdint.h>
typedef struct QCRing QCRing;
QCRing *qc_create(void);
void qc_destroy(QCRing *r);
void qc_reset(QCRing *r, double inputRate, double outputRate);
void qc_write(QCRing *r, const float *data, uint32_t count);
void qc_render(QCRing *r, float *data, uint32_t count);
float qc_level(QCRing *r);
float qc_pitch(QCRing *r);
#endif
