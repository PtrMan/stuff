
import std.stdio : writeln;
import std.conv : convertTo = parse, ConvOverflowException;
import std.string : stringCompare = icmp, stringIndexOf = indexOf;

import Token : Token;
import EscapedString : EscapedString;

class Lexer
{
   class TableElement
   {
      enum EnumWriteType
      {
         NOWRITE,
         NORMAL,
         ESCAPED
      }

      public bool Terminate;
      public EnumWriteType Write;
      public bool Read;

      public uint FollowState;


      this(bool Read, uint Write, bool Terminate, uint FollowState)
      {
         this.Read        = Read;

         if( Write == 0 )
         {
            this.Write = EnumWriteType.NOWRITE;
         }
         else if( Write == 1 )
         {
            this.Write = EnumWriteType.NORMAL;
         }
         else
         {
            this.Write = EnumWriteType.ESCAPED;
         }

         this.Terminate   = Terminate;
         this.FollowState = FollowState;
      }
   }

   public enum EnumLexerCode
   {
      OK,
      INTERNALERROR
   }
   
   this()
   {
      // fill the Lexer Table

      this.LexerTable = [
      //                    /-----       Sonderzeichen        -----\  /-----        ziff              -----\  /-----       buchstabe         -----\  /-----         :               -----\  /-----             =           -----\  /-----         <               -----\  /-----         >               -----\  /-----          Steuerz.       -----\  /-----           "             -----\  /-----             \             -----\
      /*   0 start        */new TableElement(true ,    1, true ,  0), new TableElement(true ,  1, false,  2), new TableElement(true , 1, false,  1), new TableElement(true , 1, false,  3), new TableElement(true , 1, true ,  0), new TableElement(true , 1, false,  4), new TableElement(true , 1, false,  5), new TableElement(true , 0, false,  0), new TableElement(true , 0, false, 10), new TableElement(false, 0, true, 0),
      /*   1              */new TableElement(false,    0, true ,  0), new TableElement(true ,  1, false,  1), new TableElement(true , 1, false,  1), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true, 0),
      /*   2              */new TableElement(false,    0, true ,  0), new TableElement(true ,  1, false,  2), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true, 0),
      /*   3              */new TableElement(false,    0, true ,  0), new TableElement(false,  0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(true , 1, false,  6), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true, 0),
      /*   4              */new TableElement(false,    0, true ,  0), new TableElement(false,  0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(true , 1, false,  7), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true, 0),
      /*   5              */new TableElement(false,    0, true ,  0), new TableElement(false,  0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(true , 1, false,  8), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0),      new TableElement(false, 0, true, 0),
      /*   6              */new TableElement(false,    0, true ,  0), new TableElement(false,  0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true, 0),
      /*   7              */new TableElement(false,    0, true ,  0), new TableElement(false,  0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true, 0),
      /*   8              */new TableElement(false,    0, true ,  0), new TableElement(false,  0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true, 0),
      /*   9 ":" read     */new TableElement(false,    0, true ,  0), new TableElement(false,  0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true, 0),
      /*  10 inside "..." */new TableElement(true ,    1, false, 10), new TableElement(true ,  1, false, 10), new TableElement(true , 1, false, 10), new TableElement(true , 1, false, 10), new TableElement(true , 1, false, 10), new TableElement(true , 1, false, 10), new TableElement(true , 1, false, 10), new TableElement(true , 1, false, 10), new TableElement(false, 0, true ,  0), new TableElement(true , 0, false, 12),
      /*  11 not used     */new TableElement(false,    0, true ,  0), new TableElement(false,  0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true, 0),
      /*  12 escaped char */new TableElement(false,    0, true ,  0), new TableElement(false,  0, true ,  0), new TableElement(true , 2, false, 10), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(false, 0, true ,  0), new TableElement(true , 2, false, 10), new TableElement(true , 2, false , 10)
      ];

      this.TypeTable =
      [/* 00 */ 7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,
       /* 10 */ 7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,
       /* 20 */ 7,  0,  8,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
       /* 30 */ 1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  3,  0,  5,  4,  6,  0,
       /* 40 */ 0,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
       /* 50 */ 2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  0,  9,  0,  0,  0,
       /* 60 */ 0,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
       /* 70 */ 2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  0,  0,  0,  0,  0
      ];
   }
   
   public void setSource(string Source)
   {
      this.Source = Source;

      this.Index = 0; // reset index
   }
   
   public EnumLexerCode getNextToken(ref Token OutputToken)
   {

      int convertStringToNumber(out bool Success, string String)
      {
         int Return = 0;

         Success = false;

         try
         {
            Return = convertTo!int(String);

            if( String != "" )
            {
               // error
               return 0;
            }
         }
         catch( ConvOverflowException E )
         {
            // error
            return 0;
         }

         Success = true;
         return Return;
      }

      EscapedString TempContent;
      
      bool  FirstSign = true;

      EnumLexerCode Return = EnumLexerCode.INTERNALERROR;
      
      // State of our DFA
      uint State = 0;
      
      // init Token
      OutputToken.Type = Token.EnumType.INTERNALERROR;
      OutputToken.ContentOperation = Token.EnumOperation.INTERNALERROR;
      
      // failsafe?
      OutputToken.Line = this.ActualLine;
      OutputToken.Column = this.ActualColumn;

      for(;;)
      {
         TableElement LexerTableElement;
         uint FollowState;
         
         char Sign;
         uint SignType;
         
         // check for end of file
         if( Index >= this.Source.length )
         {
            OutputToken.Line = this.ActualLine;
            OutputToken.Column = this.ActualColumn;

            OutputToken.Type = Token.EnumType.EOF;

            return EnumLexerCode.OK;
         }
                  
         Sign = this.Source[this.Index];
         
         // Convert Big Sign into Small
         // (because it is case in sensitive)
         if( (Sign >= 65) && (Sign <= 90) )
         {
            Sign += (97-65);
         }

         SignType = this.TypeTable[Sign];
         
         if( SignType == 1337 )
         {
            return Return; // error
         }
         
         writeln("State: ", State);
         writeln("SignType: ", SignType);
         writeln("---");

         // lookup the SignType in the LexerTable
         
         LexerTableElement = this.LexerTable[State*10 + SignType];

         if( LexerTableElement.Write == TableElement.EnumWriteType.NOWRITE )
         {
            // nothing
         }
         else if( LexerTableElement.Write == TableElement.EnumWriteType.NORMAL )
         {
            TempContent.append(Sign, false);

            if( FirstSign )
            {
               OutputToken.Line = this.ActualLine;
               OutputToken.Column = this.ActualColumn;
            }

            FirstSign = false;
         }
         else if( LexerTableElement.Write == TableElement.EnumWriteType.ESCAPED )
         {
            TempContent.append(Sign, true);

            if( FirstSign )
            {
               OutputToken.Line = this.ActualLine;
               OutputToken.Column = this.ActualColumn;
            }

            FirstSign = false;
         }
         
         if( LexerTableElement.Read )
         {
            this.Index++;

            if( Sign == '\n' )
            {
               this.ActualLine++;
               this.ActualColumn = 0;
            }
            else
            {
               this.ActualColumn++;
            }
         }

         
         // check if we have to terminate the DFA
         if( LexerTableElement.Terminate )
         {
            break;
         }

         State = LexerTableElement.FollowState;
         
      }

      if( State == 0 ) // invalid or Special Character ( = * / + - )
      {
         uint Index;

         assert(TempContent.getContent().length == 1, "The Length of TempContent must be 1!");

         Index = stringIndexOf("+-*/;,!?.=()#", TempContent.getContent()[0].Char);

         if( Index != -1 )
         {
            OutputToken.Type = Token.EnumType.OPERATION;
            OutputToken.ContentOperation = cast(Token.EnumOperation)Index;

         }
         else
         {
            // return ERROR-Token
         
            OutputToken.Type = Token.EnumType.ERROR;
         }
      }
      else if( State == 1 ) // identifier or keyword
      {
         bool IsKeyword;
         uint KeywordIndex;

         this.getKeyword(TempContent.convertToString(), IsKeyword, KeywordIndex);
         if( !IsKeyword )
         {
            OutputToken.Type = Token.EnumType.IDENTIFIER;
            OutputToken.ContentString = TempContent.convertToString();
         }
         else
         {
            OutputToken.Type = Token.EnumType.KEYWORD;
            OutputToken.ContentKeyword = cast(Token.EnumKeyword)KeywordIndex;
         }
      }
      else if( State == 2 ) // Number
      {
         int Number;
         bool CalleeSuccess;
         
         Number = convertStringToNumber(CalleeSuccess, TempContent.convertToString());

         if( !CalleeSuccess )
         {
            OutputToken.Type = Token.EnumType.ERROR;
         }
         else
         {
            OutputToken.Type = Token.EnumType.NUMBER;
            OutputToken.ContentNumber = Number;
         }
      }
      else if( State == 3 ) // :=
      {
         OutputToken.Type = Token.EnumType.OPERATION;
         OutputToken.ContentOperation = Token.EnumOperation.ASSIGNMENT;
      }
      else if( State == 4 ) // <
      {
         OutputToken.Type = Token.EnumType.OPERATION;
         OutputToken.ContentOperation = Token.EnumOperation.SMALLER;
      }
      else if( State == 5 ) // >
      {
         OutputToken.Type = Token.EnumType.OPERATION;
         OutputToken.ContentOperation = Token.EnumOperation.GREATER;
      }
      else if( State == 6 ) // :=
      {
         OutputToken.Type = Token.EnumType.OPERATION;
         OutputToken.ContentOperation = Token.EnumOperation.ASSIGNMENT;
      }
      else if( State == 7 ) // <=
      {
         OutputToken.Type = Token.EnumType.OPERATION;
         OutputToken.ContentOperation = Token.EnumOperation.SMALLEREQUAL;
      }
      else if( State == 8 ) // >=
      {
         OutputToken.Type = Token.EnumType.OPERATION;
         OutputToken.ContentOperation = Token.EnumOperation.GREATEREQUAL;
      }
      else if( State == 9 )
      {
         OutputToken.Type = Token.EnumType.OPERATION;
         OutputToken.ContentOperation = Token.EnumOperation.UNEQUAL;
      }
      /*else if( State == 10 )
      {
         // syntax error

         OutputToken.Type = Token.EnumType.ERROR;
      }*/
      else if( State == 10 ) // string , "..."
      {
         OutputToken.Type = Token.EnumType.STRING;
         OutputToken.ContentEscapedString = TempContent;
      }
      else
      {
         // internal error
         return Return;
      }
      
      return EnumLexerCode.OK;
   }

   // checks if Text is a keyword
   // IsKeyword will be true if it is an keyword and Index will be the index in KeywordOffsets of the keyword
   private void getKeyword(string Text, out bool IsKeyword, out uint Index)
   {
      uint IndexMin, IndexMax, IndexMid;
      int CompareResult;
      string KeywordDataString;

      IsKeyword = false;
      Index = 0;

      IndexMin = 0;
      IndexMax = Token.KeywordString.length;

      for(;;)
      {
         IndexMid = IndexMin + (IndexMax - IndexMin) / 2;

         KeywordDataString = Token.KeywordString[IndexMid];

         CompareResult = stringCompare(Text, KeywordDataString);

         if( CompareResult == 0 ) // equal
         {
            IsKeyword = true;
            Index = IndexMid;

            return;
         }
         else if( CompareResult < 0 )
         {
            if( IndexMax == IndexMid )
            {
               break;
            }

            IndexMax = IndexMid;
         }
         else
         {
            if( IndexMin == IndexMid )
            {
               break;
            }

            IndexMin = IndexMid;
         }
      }
   }
   
   // Action that the DFA does
   
   const uint ActionWrite = 1<<6;
   const uint ActionRead = 1<<7;
   const uint ActionTerminate = 1<<5;
   
   private string Source;
   
   private uint Index = 0;
   
   private TableElement[13*10] LexerTable;

   private uint[16*8] TypeTable;
   
   // position in Source File
   private string ActualFilename = "<stdin>";
   private uint ActualLine = 1;
   private uint ActualColumn = 0;
}
