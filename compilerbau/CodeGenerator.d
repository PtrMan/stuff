import std.file : write;

// for debugging
import std.stdio : writeln;

import Stack : Stack;
import EscapedString : EscapedString;

class CodeGenerator
{
   private enum EnumOpCodes
   {
      // NOTE< comments are from professor beck >
      PUSHVALVARLOCAL   =  0, /* 00 (short Displ)  [Kellern Wert lokale  Variable]             */
      PUSHVALVARMAIN    =  1, /* 01 (short Displ)  [Kellern Wert Main    Variable]             */
      PUSHVALVARGLOBAL  =  2, /* 02 (short Displ,short Proc)  [Kellern Wert globale Variable]  */
      PUSHADDRVARLOCAL  =  3, /* 03 (short Displ)  [Kellern Adresse lokale  Variable]          */
      PUSHADDRVARMAIN   =  4, /* 04 (short Displ)  [Kellern Adresse Main    Variable]          */
      PUSHADDRVARGLOBAL =  5, /* 05 (short Displ,short Proc) [Kellern Adresse globale Variable]*/
      PUSHCONSTANT      =  6, /* 06 (short Index)  [Kellern einer Konstanten]                  */
      STOREVAL          =  7, /* 07 ()           [Speichern Wert -> Adresse, beides aus Keller]*/
      PUTVAL            =  8, /* 08 ()           [Ausgabe eines Wertes aus Keller nach stdout] */
      GETVAL            =  9, /* 09 ()           [Eingabe eines Wertes von  stdin -> Keller ]  */
      /*--- arithmetische Befehle ---*/
      VZMINUS           = 10, /* 0A ()           [Vorzeichen -]                                */
      ODD               = 11, /* 0B ()           [ungerade -> 0/1]                             */
      /*--- binaere Operatoren kellern 2 Operanden aus und das Ergebnis ein ----*/
      OPADD             = 12, /* 0C ()           [Addition]                                    */
      OPSUB             = 13, /* 0D ()           [Subtraktion ]                                */
      OPMUL             = 14, /* 0E ()           [Multiplikation ]                             */
      OPDIV             = 15, /* 0F ()           [Division ]                                   */
      CMPEQ             = 16, /* 10 ()           [Vergleich = -> 0/1]                          */
      CMPNE             = 17, /* 11 ()           [Vergleich # -> 0/1]                          */
      CMPLT             = 18, /* 12 ()           [Vergleich < -> 0/1]                          */
      CMPGT             = 19, /* 13 ()           [Vergleich > -> 0/1]                          */
      CMPLE             = 20, /* 14 ()           [Vergleich <=-> 0/1]                          */
      CMPGE             = 21, /* 15 ()           [Vergleich >=-> 0/1]                          */
      /*--- Sprungbefehle ---*/
      CALL              = 22, /* 16 (short ProzNr) [Prozeduraufruf]                            */
      RETPROC           = 23, /* 17 ()           [Ruecksprung]                                 */
      JMP               = 24, /* 18 (short RelAdr) [SPZZ innerhalb der Funktion]               */
      JNOT              = 25, /* 19 (short RelAdr) [SPZZ innerhalb der Funkt.,Beding.aus Keller]*/
      ENTRYPROC         = 26, /* 1A (short lenCode,short ProcIdx,short lenVar)                 */
      PUTSTRING         = 27, /* 1B (char[])                                                   */
      ENDOFCODE         = 28  /* 1C */
   }

   private static const string[] OpCodesString = [
   "PUSHVALVARLOCAL",
   "PUSHVALVARMAIN",
   "PUSHVALVARGLOBAL",
   "PUSHADDRVARLOCAL",
   "PUSHADDRVARMAIN",
   "PUSHADDRVARGLOBAL",
   "PUSHCONSTANT",
   "STOREVAL",
   "PUTVAL",
   "GETVAL",
   "VZMINUS",
   "ODD",
   "OPADD",
   "OPSUB",
   "OPMUL",
   "OPDIV",
   "CMPEQ",
   "CMPNE",
   "CMPLT",
   "CMPGT",
   "CMPLE",
   "CMPGE",
   "CALL",
   "RETPROC",
   "JMP",
   "JNOT",
   "ENTRYPROC",
   "PUTSTRING",
   "ENDOFCODE"];

   this()
   {
      this.OutputBytecode ~= 0;
      this.OutputBytecode ~= 0;
      this.OutputBytecode ~= 0;
      this.OutputBytecode ~= 0;

      this.LabelStack = new Stack!uint();
   }

   public void pushLabel()
   {
      this.LabelStack.push(this.Bytecode.length);
   }

   public void popLabel(ref uint Return, ref bool Success)
   {
      this.LabelStack.pop(Return, Success);
   }

   public uint getAddress()
   {
      return this.Bytecode.length;
   }

   public void overwrite2At(short Data, uint Address, ref bool Success)
   {
      short *DataPtr;

      Success = false;

      DataPtr = &Data;

      if( this.Bytecode.length < 2 )
      {
         return;
      }

      if( Address > (this.Bytecode.length-2) )
      {
         return;
      }

      this.Bytecode[Address  ] = (cast(ubyte*)DataPtr)[0];
      this.Bytecode[Address+1] = (cast(ubyte*)DataPtr)[1];

      Success = true;
   }

   public void writeOpCode(ref bool Success, EnumOpCodes OpCode, int Parameters[])
   {
      uint ParametersI;
      //uint Parameters;

      //Parameters = 0;

      Success = false;

      // debug it
      writeln("OpCode=", CodeGenerator.OpCodesString[cast(uint)OpCode]);

      this.write1(this.Bytecode, cast(int)OpCode);

      switch(OpCode)
      {
         // OpCode with 3 Parameters
         case EnumOpCodes.ENTRYPROC:
         //Parameters = 3;
         //this.write2(this.Bytecode, Parameter3);

         // OpCode with 2 Parameters
         case EnumOpCodes.PUSHVALVARGLOBAL:
         case EnumOpCodes.PUSHADDRVARGLOBAL:
         //Parameters = 2;
         //this.write2(this.Bytecode, Parameter2);

         // OpCode with 1 Parameter

         case EnumOpCodes.PUSHVALVARMAIN:
         case EnumOpCodes.PUSHADDRVARMAIN:
         case EnumOpCodes.PUSHVALVARLOCAL:
         case EnumOpCodes.PUSHADDRVARLOCAL:
         case EnumOpCodes.PUSHCONSTANT:
         case EnumOpCodes.JMP:
         case EnumOpCodes.JNOT:
         case EnumOpCodes.CALL:
         //Parameters = 1;
         //this.write2(this.Bytecode, Parameter1);

         Success = true;
         break;

         case EnumOpCodes.STOREVAL:
         case EnumOpCodes.PUTVAL:
         case EnumOpCodes.GETVAL:
         case EnumOpCodes.VZMINUS:
         case EnumOpCodes.ODD:
         case EnumOpCodes.OPADD:
         case EnumOpCodes.OPSUB:
         case EnumOpCodes.OPMUL:
         case EnumOpCodes.OPDIV:
         case EnumOpCodes.CMPEQ:
         case EnumOpCodes.CMPNE:
         case EnumOpCodes.CMPLT:
         case EnumOpCodes.CMPGT:
         case EnumOpCodes.CMPLE:
         case EnumOpCodes.CMPGE:
         case EnumOpCodes.RETPROC:
         case EnumOpCodes.PUTSTRING:
         case EnumOpCodes.ENDOFCODE:

         Success = true;
         break;

         default:
         // nothing
      }

      foreach( int Parameter; Parameters )
      {
         this.write2(this.Bytecode, cast(short)Parameter);
      }

      // just for debugging
      ParametersI = 0;
      foreach( int Parameter; Parameters )
      {
         writeln("   Parameters[", ParametersI, "]=", Parameter);

         ParametersI++;
      }
   }

   private void write2(ref ubyte Place[], short Data)
   {
      short *DataPtr;

      DataPtr = &Data;

      Place ~= (cast(ubyte*)DataPtr)[0];
      Place ~= (cast(ubyte*)DataPtr)[1];
   }

   public void writeString(EscapedString String, out bool Success)
   {
      uint i;
      bool CalleeSuccess;

      Success = false;

      // write string out
      foreach( EscapedString.EscapedChar Char; String.getContent() )
      {
         if( Char.Escaped )
         {
            if( Char.Char == 'n' ) // new line
            {
               this.write1(this.Bytecode, 10);
            }
            else
            {
               return;
            }
         }
         else
         {
            this.write1(this.Bytecode, Char.Char);
         }
      }

      // write terminating 0
      this.write1(this.Bytecode, 0);

      Success = true;
   }

   private void write1(ref ubyte Place[], int Data)
   {
      Place ~= cast(ubyte)Data;
   }

   public void finishProcedureAndFlush()
   {
      uint CodeLength;

      CodeLength = Bytecode.length;

      // write the length of the code into the Bytecodes

      this.Bytecode[1] = cast(ubyte)CodeLength;
      this.Bytecode[2] = cast(ubyte)(CodeLength >> 8);

      // copy the Bytecode
      foreach( ubyte Byte; this.Bytecode )
      {
         this.OutputBytecode ~= Byte;
      }

      Bytecode.length = 0; // flush Bytecode
   }

   public void writeToFile(string Filename, uint NumberOfProcedures, ref ubyte ConstantBlock[])
   {
      this.OutputBytecode[0] = cast(ubyte)(NumberOfProcedures);
      this.OutputBytecode[1] = cast(ubyte)(NumberOfProcedures >> 8);
      this.OutputBytecode[2] = cast(ubyte)(NumberOfProcedures >> 16);
      this.OutputBytecode[3] = cast(ubyte)(NumberOfProcedures >> 24);

      // append constantblock
      foreach( ubyte Byte; ConstantBlock )
      {
         this.OutputBytecode ~= Byte;
      }

      write(Filename, this.OutputBytecode);

      this.OutputBytecode.length = 0;
   }

   private ubyte Bytecode[];

   private ubyte OutputBytecode[];

   private Stack!uint LabelStack;
}
