#ifndef H_ABSTRACTPIN
#define H_ABSTRACTPIN

class AbstractPin
{
   public:
   // this is used to set the pin to a specific output
   virtual void setValue(bool Value) = 0;

   // this is unsed to get a value from the pin
   // must only be implemented for input pins
   virtual bool getValue();

   // TODO< build enum for Type (c++0x)
   // Type is the type
   //  Output : 0
   //  Input : 1

   virtual void configure(unsigned Type);
};

#endif
