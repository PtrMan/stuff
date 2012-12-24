// Stack.d v0

template Stack(ValueType)
{
   public class Stack
   {
      private ValueType []Values;

      void push(ValueType Value)
      {
         this.Values ~= Value;
      }

      void pop(ref ValueType Return, ref bool Success)
      {
         Success = false;

         if( this.Values.length == 0 )
         {
            return;
         }

         Return = this.Values[this.Values.length-1];
         this.Values.length--;

         Success = true;

         return;
      }

      void getTop(ref ValueType Return, ref bool Success)
      {
         Success = false;

         if( this.Values.length == 0 )
         {
            return;
         }

         Return = this.Values[this.Values.length-1];

         Success = true;
         return;
      }

      void setTop(ValueType Value, ref bool Success)
      {
         Success = false;

         if( this.Values.length == 0 )
         {
            return;
         }

         this.Values[this.Values.length-1] = Value;

         Success = true;
         return;
      }

      uint getCount()
      {
         return this.Values.length;
      }
   }
}
