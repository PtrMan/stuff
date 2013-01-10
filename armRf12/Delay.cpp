#include "Delay.h"

//#include "DataWatchTrace.h"

void delayMs(unsigned Ms)
{

   //const unsigned CLOCKSPERMS = 16000000/1000;
   //DataWatchTrace::waitCycles(CLOCKSPERMS*Ms);

   // TODO< use timer >
   /*
   unsigned i;
   unsigned Max;

   Max = Ms * 1000;

   for( i = 0; i < Max; i++);
   */
   delayUs(Ms * 1000);
}

void delayUs(unsigned Us)
{
   unsigned i;
   unsigned Max;

   Max = Us;

   for( i = 0; i < Max; i++);
}
