/*
my own hash function, is not optimal

template Hashable(string)
{
   uint hash(ref string Data)
   {
      uint i;
      uint Hash = 0x5FA7;

      for( i = 0; i < Data.length; i++ )
      {
         uint Temp;
         uint Bit;

         Temp = cast(uint)Data[i];

         if( i & 1 )
         {
            Hash ^= Temp;
         }
         else
         {
            // rol Hash to left
            Bit = (Hash>>31) & 1;
            Hash <<= 1;
            Hash |= Bit;
   
            // xor it
            Hash ^= Temp;
         }
      }

      return Hash;
   }
}
*/

// from http://stackoverflow.com/questions/2624192/good-hash-function-for-strings
template Hashable(string)
{
   uint hash(ref string Data)
   {
      uint Hash = 7;

      foreach( uint Char; Data)
      {
         Hash = Hash*31 + Char;
      }

      return Hash;
    }
}

template Hashtable(KeyType, ValueType, uint Size)
{
   public class Hashtable
   {
      private BucketContent[Size] Content;
      
      public this()
      {
         uint i;

         for( i = 0; i < Size; i++ )
         {
            this.Content[i] = null;
         }
      }

      public void add(KeyType Key, ValueType Value)
      {
         uint HashIndex;
         BucketContent ActualBucketContent;

         HashIndex = Hashable!KeyType.hash(Key);

         HashIndex %= Size;

         ActualBucketContent = this.Content[HashIndex];

         if( ActualBucketContent is null )
         {
         	// if the Bucket is not created until now we create it

            this.Content[HashIndex] = new BucketContent();
            this.Content[HashIndex].Value = Value;
            this.Content[HashIndex].Key = Key;
            this.Content[HashIndex].Next = null;

            return;
         }

         // else we search for the end and append a new Content
         for(;;)
         {
            if( ActualBucketContent.Next is null )
            {
               break;
            }

            ActualBucketContent = ActualBucketContent.Next;
         }

         ActualBucketContent.Next = new BucketContent();
         ActualBucketContent.Next.Next = null;
         ActualBucketContent.Next.Key = Key;
         ActualBucketContent.Next.Value = Value;

         return;
      }

      // returns also the Value for the Key if it was found, if not, "Value" is undefined!
      public bool contains(KeyType Key, ref ValueType Value)
      {
         uint HashIndex;
         BucketContent ActualBucketContent;

         HashIndex = Hashable!KeyType.hash(Key);

         HashIndex %= Size;

         ActualBucketContent = this.Content[HashIndex];

         for(;;)
         {
            if( ActualBucketContent is null )
            {
               return false;
            }

            if( ActualBucketContent.Key == Key )
            {
               Value = ActualBucketContent.Value;
            	return true;
            }

            ActualBucketContent = ActualBucketContent.Next;
         }
         
         // never reached
         return false;
      }
   }

   private class BucketContent
   {
      public KeyType Key; // can't be null
      public ValueType Value; // can't be null

      // can be null if the chain ends here
      public BucketContent Next;
   }
}

import std.stdio : writeln;

/* Code for testing

void main()
{
   Hashtable!(string, uint, 512) Table = new Hashtable!(string, uint, 512)();
   bool Success;
   uint ReturnValue;

   if( Table.contains("check", ReturnValue) )
   {
      writeln("Test: check not contained failed!");
      return;
   }

   Table.add("check", 1337);

   if( !Table.contains("check", ReturnValue) )
   {
      writeln("Test: check contained failed!");
      return;
   }
}
*/
