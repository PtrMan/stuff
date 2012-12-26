// for debugging
import std.stdio : writeln;

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

   public void writeOpCode(ref bool Success, EnumOpCodes OpCode, int Parameter1 = 0, int Parameter2 = 0, int Parameter3 = 0)
   {
      uint Parameters;

      Parameters = 0;

      Success = false;

      // debug it
      writeln("OpCode=", CodeGenerator.OpCodesString[cast(uint)OpCode]);

      this.write(cast(int)OpCode);

      switch(OpCode)
      {
         // OpCode with 3 Parameters
         case EnumOpCodes.ENTRYPROC:
         Parameters = 3;
         this.write(Parameter3);

         // OpCode with 2 Parameters
         case EnumOpCodes.PUSHVALVARGLOBAL:
         case EnumOpCodes.PUSHADDRVARGLOBAL:
         Parameters = 2;
         this.write(Parameter2);

         // OpCode with 1 Parameter

         case EnumOpCodes.PUSHVALVARMAIN:
         case EnumOpCodes.PUSHADDRVARMAIN:
         case EnumOpCodes.PUSHVALVARLOCAL:
         case EnumOpCodes.PUSHADDRVARLOCAL:
         case EnumOpCodes.PUSHCONSTANT:
         case EnumOpCodes.JMP:
         case EnumOpCodes.JNOT:
         case EnumOpCodes.CALL:
         Parameters = 1;
         this.write(Parameter1);

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

      if( Parameters > 0 )
      {
         writeln("   Parameters[0]=", Parameter1);
      }
      if( Parameters > 1 )
      {
         writeln("   Parameters[1]=", Parameter2);
      }
      if( Parameters == 2 )
      {
         writeln("   Parameters[2]=", Parameter3);
      }
   }

   private void write(int Data)
   {
      this.Bytecode ~= cast(ubyte)Data;
      this.Bytecode ~= cast(ubyte)(Data >> 8);
   }

   private ubyte Bytecode[];
}
