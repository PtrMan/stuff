#ifndef H_RF12
#define H_RF12

#include "AbstractPin.h"

class Rf12
{
   public:
   unsigned transmit(unsigned short Value);

   void init(AbstractPin *SdoPin, AbstractPin *SdiPin, AbstractPin *ClkPin, AbstractPin *CsPin);

   void setbandwidth(unsigned Bandwidth, unsigned Gain, unsigned Drssi);
   void setbaud(unsigned Baud);
   void setfreq(unsigned Freq);

   void setpower(unsigned Power, unsigned Mod);

   void ready(unsigned Sending);

   void txdata(unsigned char *data, unsigned Count);
   void rxdata(unsigned char *data, unsigned Count);

   // NOTE< just because of probelsm public >
   static unsigned char hamminge[16];
   static unsigned char hammingd[256];
   private:
   

   AbstractPin *SdoPin, *SdiPin, *ClkPin, *CsPin;
};

#endif
