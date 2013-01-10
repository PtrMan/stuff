import Nullable : Nullable;
import Token : Token;
import Stack : Stack;
import Lexer : Lexer;
import Line : Line;

import NameListProcedure : NameListProcedure;
import NameListObject : NameListObject;
import NameListConst : NameListConst;
import NameListVariable : NameListVariable;

import CodeGenerator : CodeGenerator;

// just for debugging
import std.stdio : writeln;


import std.string : leftJustify;

// exceptions?
import std.conv : to;

class Parser
{
   class Arc
   {
      enum EnumType
      {
         TOKEN,
         OPERATION,  // TODO< is actualy symbol? >
         ARC,        // another arc, info is the index of the start
         KEYWORD,    // Info is the id of the Keyword

         END,        // Arc end
         NIL,        // Nil Arc

         ERROR       // not used Arc
      }

      public EnumType Type;

      public void delegate(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage) Callback;
      public Nullable!uint Next;
      public Nullable!uint Alternative;

      public uint Info; // Token Type, Operation Type and so on

      this(EnumType Type, uint Info, void delegate(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage) Callback, Nullable!uint Next, Nullable!uint Alternative)
      {
         this.Type        = Type;
         this.Info        = Info;
         this.Callback    = Callback;
         this.Next        = Next;
         this.Alternative = Alternative;
      }
   }

   this()
   {
      void procedureEnd(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         bool CalleeSuccess;

         // TODO< append code? >
         
         Success = false;

         // generate Code RETPROC
         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.RETPROC, []);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         // write length and append code
         ParserObj.CodeGen.finishProcedureAndFlush();

         // MAYBE< ??? remove all namelist elements but the first Proceduredescription ??? >


         // TODO< nulltest? >

         ParserObj.CurrentProcedure = ParserObj.CurrentProcedure.Parent;



         writeln("procedureEnd called!");

         Success = true;
      }

      this.CallbackProcedureEnd = &procedureEnd;

      this.fill();

      this.Lines ~= new Line();

      this.RootProcedure = this.CurrentProcedure = new NameListProcedure();

      this.CodeGen = new CodeGenerator();
   }

   // returns false on fail and true on success
   bool fill()
   {
      void nothing(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         Success = true;
      }

      //////////
      // program
      //////////

      void programEnd(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         ubyte ConstantArray[];
         bool CalleeSuccess;

         Success = false;

         ParserObj.CallbackProcedureEnd(ParserObj, CurrentToken, CalleeSuccess, ErrorMessage);

         if( !CalleeSuccess )
         {
            return;
         }

         writeln("Lenght of constant array ", ParserObj.ConstContent.length);

         foreach( int Constant; ParserObj.ConstContent )
         {
            int *ConstantPtr;

            ConstantPtr = &Constant;

            ConstantArray ~= (cast(ubyte*)(ConstantPtr))[0];
            ConstantArray ~= (cast(ubyte*)(ConstantPtr))[1];
            ConstantArray ~= (cast(ubyte*)(ConstantPtr))[2];
            ConstantArray ~= (cast(ubyte*)(ConstantPtr))[3];
         }

         writeln(ConstantArray.length);

         ParserObj.CodeGen.writeToFile("output.cl0", ParserObj.ProcedureCounter, ConstantArray);

         Success = true;
      }

      //////////
      // Block
      //////////

      void procedureConstA(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         NameListObject CurrentNameListObject;
         bool IdentifierKnown;

         Success = false;

         IdentifierKnown = ParserObj.CurrentProcedure.Entities.contains(CurrentToken.ContentString, CurrentNameListObject);
         if( IdentifierKnown )
         {
            ErrorMessage = "Identifier was allready assigned!";
            return;
         }

         // save the Identifier
         ParserObj.TempIdentifier = CurrentToken.ContentString;

         Success = true;
      }

      void procedureConstB(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         NameListConst CreatedConst;
         uint IConst;
         int ConstValue;
         bool Found;

         Found = false;
         ConstValue = CurrentToken.ContentNumber;

         for( IConst = 0; IConst < ParserObj.ConstContent.length; IConst++ )
         {
            if( ParserObj.ConstContent[IConst] == ConstValue )
            {
               Found = true;
               break;
            }
         }

         if( !Found )
         {
            ParserObj.ConstContent ~= ConstValue;
         }

         CreatedConst = new NameListConst(CurrentToken.ContentNumber, IConst*4);

         ParserObj.CurrentProcedure.Entities.add(ParserObj.TempIdentifier, CreatedConst);

         Success = true;
      }

      void procedureVar(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         string VariableName;
         bool IdentifierKnown;
         NameListObject TempNameListObject;
         NameListVariable CreatedVariable;

         Success = false;

         VariableName = CurrentToken.ContentString;

         // check if the name is allready declared

         IdentifierKnown = ParserObj.CurrentProcedure.Entities.contains(VariableName, TempNameListObject);

         if( IdentifierKnown )
         {
            ErrorMessage = "Variablename is allready used!";
            return;
         }

         CreatedVariable = new NameListVariable(ParserObj.CurrentProcedure.MemoryCounter);

         ParserObj.CurrentProcedure.MemoryCounter += 4;

         ParserObj.CurrentProcedure.Entities.add(VariableName, CreatedVariable);

         Success = true;
      }

      void procedureName(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         string ProcedureName;
         NameListObject TempNameListObject;
         NameListProcedure CreatedProcedure;
         bool IdentifierKnown;

         Success = false;

         ProcedureName = CurrentToken.ContentString;

         // check if the name is allready declared

         IdentifierKnown = ParserObj.CurrentProcedure.Entities.contains(ProcedureName, TempNameListObject);

         if( IdentifierKnown )
         {
            ErrorMessage = "Name is allready used!";
            return;
         }

         CreatedProcedure = new NameListProcedure();
         CreatedProcedure.Parent = ParserObj.CurrentProcedure;
         CreatedProcedure.ProcedureIndex = ParserObj.ProcedureCounter++;

         writeln(ProcedureName, " added");

         ParserObj.CurrentProcedure.Entities.add(ProcedureName, CreatedProcedure);

         ParserObj.CurrentProcedure = CreatedProcedure;

         Success = true;
      }

      

      void blockEntry(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         bool CalleeSuccess;

         Success = false;

         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.ENTRYPROC, [0, ParserObj.CurrentProcedure.ProcedureIndex, ParserObj.CurrentProcedure.MemoryCounter]);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         Success = true;
      }


      //////////
      // Statement
      //////////

      void statementAssignmentLeft(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         string Identifier;
         bool Found;
         NameListObject FoundNameListObject;
         NameListVariable FoundVariable;
         NameListProcedure ScopeProcedure;
         bool FoundLocal; // if this is true it means that the variable was found in the local scope
         bool CalleeSuccess;

         Success = false;

         writeln("statement assignment left called");

         Identifier = CurrentToken.ContentString;

         // search the identifier globaly

         ParserObj.searchIdentifierGlobal(Identifier, FoundNameListObject, FoundLocal, Found, ScopeProcedure);

         if( !Found )
         {
            ErrorMessage = "Variablename was not defined!";
            return;
         }

         // check if the Found NameListObject is a Variable

         if( FoundNameListObject.Type != NameListObject.EnumType.VARIABLE )
         {
            ErrorMessage = "Left side must ba a Variable!";
            return;
         }

         FoundVariable = cast(NameListVariable)FoundNameListObject;

         // Generate the Code

         if( FoundLocal )
         {
            ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.PUSHADDRVARLOCAL, [FoundVariable.Displacement]);

            if( !CalleeSuccess )
            {
               ErrorMessage = "Internal Error";
               return;
            }
         }
         else
         {
            ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.PUSHADDRVARGLOBAL, [FoundVariable.Displacement, ScopeProcedure.ProcedureIndex/*CurrentProcedure.ProcedureIndex*/]);

            if( !CalleeSuccess )
            {
               ErrorMessage = "Internal Error";
               return;
            }
         }

         Success = true;
      }

      void statementAssignmentRight(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         bool CalleeSuccess;

         Success = false;

         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.STOREVAL, []);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         Success = true;
      }

      void statementCall(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         string Identifier;
         NameListObject FoundNameListObject;
         NameListProcedure FoundProcedure, ScopeProcedure;
         bool FoundLocal, Found, CalleeSuccess;

         Success = false;

         Identifier = CurrentToken.ContentString;

         ParserObj.searchIdentifierGlobal(Identifier, FoundNameListObject, FoundLocal, Found, ScopeProcedure);

         if( !Found )
         {
            ErrorMessage = "Procedurename was not defined!";
            return;
         }

         if( FoundNameListObject.Type != NameListObject.EnumType.PROCEDURE )
         {
            ErrorMessage = "Identifier must be the name of a Procedure!";
            return;
         }

         FoundProcedure = cast(NameListProcedure)FoundNameListObject;

         // Generate code
         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.CALL, [FoundProcedure.ProcedureIndex]);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         Success = true;
      }

      void statementIfCondition(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         bool CalleeSuccess;

         Success = false;

         ParserObj.CodeGen.pushLabel();

         // Generate code
         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.JNOT, [0]);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         Success = true;
      }

      void statementIfStatement(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         uint LabelAddress;
         uint CurrentAddress;
         uint AddressDifference;
         bool CalleeSuccess;

         Success = false;

         ParserObj.CodeGen.popLabel(LabelAddress, CalleeSuccess);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         CurrentAddress = ParserObj.CodeGen.getAddress();

         // calculate the difference

         // assert((CurrentAddress - LabelAddress) >= 3)

         AddressDifference = CurrentAddress - LabelAddress - 3;

         ParserObj.CodeGen.overwrite2At(cast(short)AddressDifference, LabelAddress+1, CalleeSuccess);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         Success = true;
      }

      void statementWhileBegin(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         Success = true;

         ParserObj.CodeGen.pushLabel();
      }

      void statementWhileAfterCondition(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         bool CalleeSuccess;

         Success = false;

         ParserObj.CodeGen.pushLabel();

         // Generate code
         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.JNOT, [0]);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         Success = true;
      }

      void statementWhileAfterStatement(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         uint JNotAddress; // points at the JNOT Operation
         uint ConditionAddress; // points at the condition
         uint BeforeJmpAddress;
         uint AddressDifference;
         bool CalleeSuccess;

         Success = false;

         ParserObj.CodeGen.popLabel(JNotAddress, CalleeSuccess);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error!";
            return;
         }

         ParserObj.CodeGen.popLabel(ConditionAddress, CalleeSuccess);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error!";
            return;
         }

         BeforeJmpAddress = ParserObj.CodeGen.getAddress();

         // Generate JMP code
         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.JMP, [- (BeforeJmpAddress - ConditionAddress + 3)]);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         // overwrite JNOT destination
         AddressDifference = (BeforeJmpAddress + 3) - (JNotAddress + 3);

         ParserObj.CodeGen.overwrite2At(cast(short)AddressDifference, JNotAddress+1, CalleeSuccess);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         Success = true;
      }

      //////////
      // Expression
      //////////

      void expressionNeg(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         bool CalleeSuccess;

         Success = false;

         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.VZMINUS, []);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         Success = true;
      }

      void expressionAdd(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         bool CalleeSuccess;

         Success = false;

         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.OPADD, []);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         Success = true;
      }

      void expressionSub(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         bool CalleeSuccess;

         Success = false;

         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.OPSUB, []);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         Success = true;
      }

      //////////
      // Term
      //////////

      void termMul(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         bool CalleeSuccess;

         Success = false;

         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.OPMUL, []);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         Success = true;
      }

      void termDiv(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         bool CalleeSuccess;

         Success = false;

         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.OPDIV, []);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         Success = true;
      }

      //////////
      // Factor
      //////////

      void factorNumeral(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         uint IConst;
         int NumeralValue;
         bool Found;
         bool CalleeSuccess;

         Success = false;

         NumeralValue = CurrentToken.ContentNumber;

         // search for the constant, if not found, we add the constant

         Found = false;
         for( IConst = 0; IConst < ParserObj.ConstContent.length; IConst++ )
         {
            if( ParserObj.ConstContent[IConst] == NumeralValue )
            {
               Found = true;
               break;
            }
         }

         if( !Found )
         {
            ParserObj.ConstContent ~= NumeralValue;
         }

         // generate code

         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.PUSHCONSTANT, [IConst*4]);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         Success = true;
      }

      void factorIdentifier(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         string Identifier;
         NameListObject FoundNameListObject;
         NameListProcedure ScopeProcedure;
         bool FoundLocal; // if this is true it means that the variable was found in the local scope
         bool Found;

         Success = false;

         Identifier = CurrentToken.ContentString;
         // search the identifier globaly

         ParserObj.searchIdentifierGlobal(Identifier, FoundNameListObject, FoundLocal, Found, ScopeProcedure);

         if( !Found )
         {
            ErrorMessage = "Variablename or Constantname was not defined!";
            return;
         }
         
         // check if the Found NameListObject is a Variable or a Constant

         if( FoundNameListObject.Type == NameListObject.EnumType.VARIABLE )
         {
            NameListVariable FoundVariable;
            bool CalleeSuccess;

            FoundVariable = cast(NameListVariable)FoundNameListObject;
            
            // Generate the code

            if( FoundLocal )
            {
               ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.PUSHVALVARLOCAL, [FoundVariable.Displacement]);

               if( !CalleeSuccess )
               {
                  ErrorMessage = "Internal Error";
                  return;
               }
            }
            else
            {
               ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.PUSHVALVARGLOBAL, [FoundVariable.Displacement, ScopeProcedure.ProcedureIndex/*CurrentProcedure.ProcedureIndex*/]);

               if( !CalleeSuccess )
               {
                  ErrorMessage = "Internal Error";
                  return;
               }
            }

            Success = true;
         }
         else if( FoundNameListObject.Type == NameListObject.EnumType.CONST )
         {
            NameListConst FoundConstant;
            bool CalleeSuccess;
            
            FoundConstant = cast(NameListConst)FoundNameListObject;

            // Generate the code

            ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.PUSHCONSTANT, [FoundConstant.Index]);

            if( !CalleeSuccess )
            {
               ErrorMessage = "Internal Error";
               return;
            }

            Success = true;
         }
         else
         {
            ErrorMessage = "Identifier must be the name of a Variable or Constant!";
            return;
         }
      }

      //////////
      // Input
      //////////

      void inputCallback(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         string VariableName;
         NameListObject FoundNameListObject;
         NameListVariable FoundVariable;
         bool Found, FoundLocal, CalleeSuccess;
         NameListProcedure ScopeProcedure;

         Success = false;

         VariableName = CurrentToken.ContentString;

         searchIdentifierGlobal(VariableName, FoundNameListObject, FoundLocal, Found, ScopeProcedure);

         if( !Found )
         {
            ErrorMessage = "Variablename not found!";
            return;
         }

         if( FoundNameListObject.Type != NameListObject.EnumType.VARIABLE )
         {
            ErrorMessage = "Identifier must be a Variablename!";
            return;
         }

         FoundVariable = cast(NameListVariable)FoundNameListObject;

         // Generate the code

         if( FoundLocal )
         {
            ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.PUSHADDRVARLOCAL, [FoundVariable.Displacement]);

            if( !CalleeSuccess )
            {
               ErrorMessage = "Internal Error";
               return;
            }
         }
         else
         {
            ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.PUSHADDRVARGLOBAL, [FoundVariable.Displacement, ScopeProcedure.ProcedureIndex/*CurrentProcedure.ProcedureIndex*/]);

            if( !CalleeSuccess )
            {
               ErrorMessage = "Internal Error";
               return;
            }
         }

         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.GETVAL, []);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         Success = true;
      }

      //////////
      // Output
      //////////

      void outputCallback(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         bool CalleeSuccess;

         Success = false;

         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.PUTVAL, []);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         Success = true;
      }

      void outputStringCallback(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         bool CalleeSuccess;

         Success = false;

         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.PUTSTRING, []);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         // write the content of the string out
         ParserObj.CodeGen.writeString(CurrentToken.ContentEscapedString, CalleeSuccess);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Invalid String!";
            return;
         }

         Success = true;
      }

      //////////
      // Condition
      //////////

      void conditionOdd(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         bool CalleeSuccess;

         Success = false;

         ParserObj.CodeGen.writeOpCode(CalleeSuccess, CodeGenerator.EnumOpCodes.ODD, []);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         Success = true;
      }

      void conditionEqual(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         Success = true;

         ParserObj.ConditionType = EnumCondition.EQUAL;
      }

      void conditionUnequal(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         Success = true;

         ParserObj.ConditionType = EnumCondition.NOTEQUAL;
      }

      void conditionLess(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         Success = true;

         ParserObj.ConditionType = EnumCondition.LESS;
      }

      void conditionLessEqual(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         Success = true;

         ParserObj.ConditionType = EnumCondition.LESSEQUAL;
      }

      void conditionGreater(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         Success = true;

         ParserObj.ConditionType = EnumCondition.GREATER;
      }

      void conditionGreaterEqual(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         Success = true;

         ParserObj.ConditionType = EnumCondition.GREATEREQUAL;
      }

      void conditionCodeGen(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         bool CalleeSuccess;
         CodeGenerator.EnumOpCodes OpCode;

         Success = false;

         switch( ParserObj.ConditionType )
         {
            case EnumCondition.EQUAL:
            OpCode = CodeGenerator.EnumOpCodes.CMPEQ;
            break;

            case EnumCondition.NOTEQUAL:
            OpCode = CodeGenerator.EnumOpCodes.CMPNE;
            break;

            case EnumCondition.LESS:
            OpCode = CodeGenerator.EnumOpCodes.CMPLT;
            break;

            case EnumCondition.LESSEQUAL:
            OpCode = CodeGenerator.EnumOpCodes.CMPLE;
            break;

            case EnumCondition.GREATER:
            OpCode = CodeGenerator.EnumOpCodes.CMPGT;
            break;

            case EnumCondition.GREATEREQUAL:
            OpCode = CodeGenerator.EnumOpCodes.CMPGE;
            break;

            default:
            ErrorMessage = "Internal Error";
            return;
         }

         ParserObj.CodeGen.writeOpCode(CalleeSuccess, OpCode, []);

         if( !CalleeSuccess )
         {
            ErrorMessage = "Internal Error";
            return;
         }

         ParserObj.ConditionType = Parser.EnumCondition.INVALID;

         Success = true;
      }


      Nullable!uint NullUint = new Nullable!uint(true, 0);

      // programm
      /*   0 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      ,  2                                        , &nothing, new Nullable!uint(false,   1), NullUint                     );
      /*   1 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.POINT       , &programEnd, new Nullable!uint(false,  90), NullUint                     );

      // block
      /*   2 */this.Arcs ~= new Arc(Parser.Arc.EnumType.KEYWORD  , cast(uint)Token.EnumKeyword.CONST         , &nothing, new Nullable!uint(false,   3), new Nullable!uint(false,   8));
      /*   3 */this.Arcs ~= new Arc(Parser.Arc.EnumType.TOKEN    , cast(uint)Token.EnumType.IDENTIFIER       , &procedureConstA, new Nullable!uint(false,   4), NullUint                     );
      /*   4 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.EQUAL       , &nothing, new Nullable!uint(false,   5), NullUint                     );
      /*   5 */this.Arcs ~= new Arc(Parser.Arc.EnumType.TOKEN    , cast(uint)Token.EnumType.NUMBER           , &procedureConstB, new Nullable!uint(false,   6), NullUint                     );
      /*   6 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.COMMA       , &nothing, new Nullable!uint(false,   3), new Nullable!uint(false,   7));
      /*   7 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.SEMICOLON   , &nothing, new Nullable!uint(false,   8), NullUint                     );

      /*   8 */this.Arcs ~= new Arc(Parser.Arc.EnumType.KEYWORD  , cast(uint)Token.EnumKeyword.VAR           , &nothing, new Nullable!uint(false,   9), new Nullable!uint(false,  12));
      /*   9 */this.Arcs ~= new Arc(Parser.Arc.EnumType.TOKEN    , cast(uint)Token.EnumType.IDENTIFIER       , &procedureVar, new Nullable!uint(false,  10), NullUint                     );
      /*  10 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.COMMA       , &nothing, new Nullable!uint(false,   9), new Nullable!uint(false,  11));
      /*  11 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.SEMICOLON   , &nothing, new Nullable!uint(false,  12), NullUint                     );

      /*  12 */this.Arcs ~= new Arc(Parser.Arc.EnumType.KEYWORD  , cast(uint)Token.EnumKeyword.PROCEDURE     , &nothing, new Nullable!uint(false,  13), new Nullable!uint(false,  19));
      /*  13 */this.Arcs ~= new Arc(Parser.Arc.EnumType.TOKEN    , cast(uint)Token.EnumType.IDENTIFIER       , &procedureName, new Nullable!uint(false,  14), NullUint                     );
      /*  14 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.SEMICOLON   , &nothing, new Nullable!uint(false,  15), NullUint                     );
      /*  15 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 2                                         , &nothing, new Nullable!uint(false,  16), new Nullable!uint(false,  19));
      /*  16 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.SEMICOLON   , this.CallbackProcedureEnd, new Nullable!uint(false,  12), NullUint                     );
      /*  17 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 20 /* statement */                        , &nothing, new Nullable!uint(false,  18), NullUint                     );
      /*  18 */this.Arcs ~= new Arc(Parser.Arc.EnumType.END      , 0                                         , &nothing, NullUint                     , NullUint                     );

      /*  19 */this.Arcs ~= new Arc(Parser.Arc.EnumType.NIL      , 0                                         , &blockEntry, new Nullable!uint(false,  17), NullUint                     );

      // statement
      /*  20 */this.Arcs ~= new Arc(Parser.Arc.EnumType.TOKEN    , cast(uint)Token.EnumType.IDENTIFIER       , &statementAssignmentLeft, new Nullable!uint(false,  21), new Nullable!uint(false,  24));
      /*  21 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.ASSIGNMENT  , &nothing, new Nullable!uint(false,  22), NullUint                     );
      /*  22 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 50 /* expression */                       , &statementAssignmentRight, new Nullable!uint(false,  23), NullUint                     );
      /*  23 */this.Arcs ~= new Arc(Parser.Arc.EnumType.END      , 0                                         , &nothing, NullUint                     , NullUint                     );
      /*  24 */this.Arcs ~= new Arc(Parser.Arc.EnumType.KEYWORD  , cast(uint)Token.EnumKeyword.IF            , &nothing, new Nullable!uint(false,  25), new Nullable!uint(false,  28));
      /*  25 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 80 /* condition */                        , &statementIfCondition, new Nullable!uint(false,  26), NullUint                     );
      /*  26 */this.Arcs ~= new Arc(Parser.Arc.EnumType.KEYWORD  , cast(uint)Token.EnumKeyword.THEN          , &nothing, new Nullable!uint(false,  27), NullUint                     );
      /*  27 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 20 /* statement */                        , &statementIfStatement, new Nullable!uint(false,  23), NullUint                     );
      /*  28 */this.Arcs ~= new Arc(Parser.Arc.EnumType.KEYWORD  , cast(uint)Token.EnumKeyword.WHILE         , &statementWhileBegin, new Nullable!uint(false,  29), new Nullable!uint(false,  32));
      /*  29 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 80 /* condition */                        , &statementWhileAfterCondition, new Nullable!uint(false,  30), NullUint                     );
      /*  30 */this.Arcs ~= new Arc(Parser.Arc.EnumType.KEYWORD  , cast(uint)Token.EnumKeyword.DO            , &nothing, new Nullable!uint(false,  31), NullUint                     );
      /*  31 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 20 /* statement */                        , &statementWhileAfterStatement, new Nullable!uint(false,  23), NullUint                     );
      /*  32 */this.Arcs ~= new Arc(Parser.Arc.EnumType.KEYWORD  , cast(uint)Token.EnumKeyword.BEGIN         , &nothing, new Nullable!uint(false,  33), new Nullable!uint(false,  36));
      /*  33 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 20 /* statement */                        , &nothing, new Nullable!uint(false,  34), NullUint                     ); //new Nullable!uint(false,  35));
      /*  34 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.SEMICOLON   , &nothing, new Nullable!uint(false,  33), new Nullable!uint(false,  35));//NullUint                     );
      /*  35 */this.Arcs ~= new Arc(Parser.Arc.EnumType.KEYWORD  , cast(uint)Token.EnumKeyword.END           , &nothing, new Nullable!uint(false,  23), NullUint                     );
      /*  36 */this.Arcs ~= new Arc(Parser.Arc.EnumType.KEYWORD  , cast(uint)Token.EnumKeyword.CALL          , &nothing, new Nullable!uint(false,  37), new Nullable!uint(false,  38));
      /*  37 */this.Arcs ~= new Arc(Parser.Arc.EnumType.TOKEN    , cast(uint)Token.EnumType.IDENTIFIER       , &statementCall       , new Nullable!uint(false,  23), NullUint                     );
      /*  38 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.INPUT       , &nothing             , new Nullable!uint(false,  39), new Nullable!uint(false,  40));
      /*  39 */this.Arcs ~= new Arc(Parser.Arc.EnumType.TOKEN    , cast(uint)Token.EnumType.IDENTIFIER       , &inputCallback       , new Nullable!uint(false,  23), NullUint                     );
      /*  40 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.OUTPUT      , &nothing             , new Nullable!uint(false,  42), NullUint                     );
      /*  41 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 50 /* expression */                       , &outputCallback      , new Nullable!uint(false,  23), NullUint                     );
      /*  42 */this.Arcs ~= new Arc(Parser.Arc.EnumType.TOKEN    , cast(uint)Token.EnumType.STRING           , &outputStringCallback, new Nullable!uint(false,  23), new Nullable!uint(false,  41));

      /*  43 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing             , NullUint                      , NullUint                     );
      /*  44 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing             , NullUint                      , NullUint                     );
      /*  45 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing             , NullUint                      , NullUint                     );
      /*  46 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing             , NullUint                      , NullUint                     );
      /*  47 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing             , NullUint                      , NullUint                     );
      /*  48 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing             , NullUint                      , NullUint                     );
      /*  49 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing             , NullUint                      , NullUint                     );
      
      // Expression
      /*  50 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.MINUS       , &nothing, new Nullable!uint(false,  51), new Nullable!uint(false,  52));
      /*  51 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 60 /* term */                             , &expressionNeg, new Nullable!uint(false,  53), NullUint                     );
      /*  52 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 60 /* term */                             , &nothing, new Nullable!uint(false,  53)      , NullUint                     );
      /*  53 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.PLUS        , &nothing, new Nullable!uint(false,  55), new Nullable!uint(false,  54));
      /*  54 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.MINUS       , &nothing, new Nullable!uint(false,  56), new Nullable!uint(false,  57));
      /*  55 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 60 /* term */                             , &expressionAdd, new Nullable!uint(false,  53), NullUint                     );
      /*  56 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 60 /* term */                             , &expressionSub, new Nullable!uint(false,  53), NullUint                     );
      /*  57 */this.Arcs ~= new Arc(Parser.Arc.EnumType.END      , 0                                         , &nothing, NullUint                     , NullUint                     );

      /*  58 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing, NullUint                     , NullUint                     );
      /*  59 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing, NullUint                     , NullUint                     );
      
      // Term
      /*  60 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 70 /* factor */                           , &nothing, new Nullable!uint(false,  61), NullUint                     );
      /*  61 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.MUL         , &nothing, new Nullable!uint(false,  62), new Nullable!uint(false,  63));
      /*  62 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 70 /* factor */                           , &termMul, new Nullable!uint(false,  61), NullUint                     );
      /*  63 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.DIV         , &nothing, new Nullable!uint(false,  64), new Nullable!uint(false,  65));
      /*  64 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 70 /* factor */                           , &termDiv, new Nullable!uint(false,  61), NullUint                     );
      /*  65 */this.Arcs ~= new Arc(Parser.Arc.EnumType.END      , 0                                         , &nothing, NullUint                     , NullUint                     );

      /*  66 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing, NullUint                     , NullUint                     );
      /*  67 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing, NullUint                     , NullUint                     );
      /*  68 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing, NullUint                     , NullUint                     );
      /*  69 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing, NullUint                     , NullUint                     );
      
      // factor
      /*  70 */this.Arcs ~= new Arc(Parser.Arc.EnumType.TOKEN    , cast(uint)Token.EnumType.NUMBER           , &factorNumeral, new Nullable!uint(false,  75), new Nullable!uint(false,  71));
      /*  71 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.BRACEOPEN   , &nothing, new Nullable!uint(false,  72), new Nullable!uint(false,  74));
      /*  72 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 50 /* expression */                       , &nothing, new Nullable!uint(false,  73), NullUint                     );
      /*  73 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.BRACECLOSE  , &nothing, new Nullable!uint(false,  75), NullUint                     );
      /*  74 */this.Arcs ~= new Arc(Parser.Arc.EnumType.TOKEN    , cast(uint)Token.EnumType.IDENTIFIER       , &factorIdentifier, new Nullable!uint(false,  75), NullUint                     );
      /*  75 */this.Arcs ~= new Arc(Parser.Arc.EnumType.END      , 0                                         , &nothing, NullUint                     , NullUint                     );

      /*  76 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing, NullUint                     , NullUint                     );
      /*  77 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing, NullUint                     , NullUint                     );
      /*  78 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing, NullUint                     , NullUint                     );
      /*  79 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ERROR    , 0                                         , &nothing, NullUint                     , NullUint                     );
      
      // condition
      /*  80 */this.Arcs ~= new Arc(Parser.Arc.EnumType.KEYWORD  , cast(uint)Token.EnumKeyword.ODD           , &nothing, new Nullable!uint(false,  81), new Nullable!uint(false,  82));
      /*  81 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 50 /* expression */                       , &conditionOdd, new Nullable!uint(false,  90), NullUint                     );
      /*  82 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 50 /* expression */                       , &nothing, new Nullable!uint(false,  83), NullUint                     );
      /*  83 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.EQUAL       , &conditionEqual, new Nullable!uint(false,  84), new Nullable!uint(false,  85));
      /*  84 */this.Arcs ~= new Arc(Parser.Arc.EnumType.ARC      , 50 /* expression */                       , &conditionCodeGen, new Nullable!uint(false,  90), NullUint                     );
      /*  85 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.UNEQUAL     , &conditionUnequal, new Nullable!uint(false,  84), new Nullable!uint(false,  86));
      /*  86 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.SMALLER     , &conditionLess, new Nullable!uint(false,  84), new Nullable!uint(false,  87));
      /*  87 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.SMALLEREQUAL, &conditionLessEqual, new Nullable!uint(false,  84), new Nullable!uint(false,  88));
      /*  88 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.GREATER     , &conditionGreater, new Nullable!uint(false,  84), new Nullable!uint(false,  89));
      /*  89 */this.Arcs ~= new Arc(Parser.Arc.EnumType.OPERATION, cast(uint)Token.EnumOperation.GREATEREQUAL, &conditionGreaterEqual, new Nullable!uint(false,  84), NullUint                     );

      // continue of programm
      /*  90 */this.Arcs ~= new Arc(Parser.Arc.EnumType.END      , 0                                         , &nothing, NullUint                     , NullUint                     );

      if( this.Arcs.length != 91 )
      {
         return false;
      }

      return true;
   }

   // used by delegates while parsing/compiling
   // searchs globaly for an Identifier
   
   // FoundLocal  is true of the Identifier was found in global space
   // Found       was the Identifer found
   // ScopeProcedure  is the procedure where it was Found
   public void searchIdentifierGlobal(string Identifier, ref NameListObject FoundNameListObject, ref bool FoundLocal, ref bool Found, ref NameListProcedure ScopeProcedure)
   {
      NameListProcedure CurrentProcedure;
      
      CurrentProcedure = this.CurrentProcedure;
      Found = false;
      FoundLocal = true;
      
      for(;;)
      {
         if( CurrentProcedure is null )
         {
            break;
         }

         Found |= CurrentProcedure.Entities.contains(Identifier, FoundNameListObject);
         if( Found )
         {
            ScopeProcedure = CurrentProcedure;
            break;
         }

         FoundLocal = false;
         CurrentProcedure = CurrentProcedure.Parent;
      }
   }

   public bool parse(ref string ErrorMessage)
   {
      struct StackClass
      {
         public uint Index;
         public void delegate(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage) Callback;
      }

      Stack!StackClass IndexStack;
      bool Success;
      uint CurrentIndex;
      Arc CurrentArc;
      
      Token CurrentToken;
      bool CalleeSuccess;

      bool CallbackSuccess;
      string CallbackErrorMessage;

      void nothing(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage)
      {
         Success = true;
      }

      IndexStack = new Stack!StackClass();
      CurrentToken = new Token();

      // set the start index
      StackClass StackContent;
      StackContent.Index = 0;
      StackContent.Callback = &nothing;

      IndexStack.push(StackContent);

      // read first token
      this.eatToken(CurrentToken, CalleeSuccess);
      if( !CalleeSuccess )
      {
         ErrorMessage = "Internal Error!\n";
         return false;
      }

      for(;;)
      {
         IndexStack.getTop(StackContent, Success);
         if( !Success )
         {
            // Internal Error
            ErrorMessage = "Internal Error!";
            return false;
         }

         // execute the callback
         CallbackSuccess = false;
         StackContent.Callback(this, CurrentToken, CallbackSuccess, CallbackErrorMessage);

         if( !CallbackSuccess )
         {
            // build complete error message
            this.buildErrorMessage(ErrorMessage, false);
            ErrorMessage ~= CallbackErrorMessage;

            return false;
         }

         CurrentIndex = StackContent.Index;

         //writeln("CurrentIndex: ", CurrentIndex);

         CurrentArc = this.Arcs[CurrentIndex];

         if( CurrentArc.Type == Parser.Arc.EnumType.NIL )
         {
            if( CurrentArc.Next.isNull() )
            {
               // Internal Error
               ErrorMessage = "Internal Error!";
               return false;
            }

            StackContent.Index = CurrentArc.Next.Value;
            StackContent.Callback = &nothing;

            IndexStack.setTop(StackContent, Success);
            if( !Success )
            {
               // Internal Error
               ErrorMessage = "Internal Error!";
               return false;
            }

            // execute callback
            CallbackSuccess = false;
            CurrentArc.Callback(this, CurrentToken, CallbackSuccess, CallbackErrorMessage);

            if( !CallbackSuccess )
            {
               // build complete error message
               this.buildErrorMessage(ErrorMessage, false);
               ErrorMessage ~= CallbackErrorMessage;
            
               return false;
            }

            continue;
         }
         else if( CurrentArc.Type == Parser.Arc.EnumType.ARC )
         {
            if( CurrentArc.Next.isNull() )
            {
               // Internal Error
               ErrorMessage = "Internal Error!";
               return false;
            }

            StackContent.Index = CurrentArc.Next.Value;
            StackContent.Callback = CurrentArc.Callback;

            IndexStack.setTop(StackContent, Success);
            if( !Success )
            {
               // Internal Error
               ErrorMessage = "Internal Error!";
               return false;
            }

            StackContent.Index = CurrentArc.Info;
            StackContent.Callback = &nothing;

            IndexStack.push(StackContent);

            continue;
         }
         else if( CurrentArc.Type == Parser.Arc.EnumType.OPERATION )
         {
            // check for internal error token
            if( CurrentToken.Type == Token.EnumType.INTERNALERROR )
            {
               ErrorMessage = "Internal Error!";
               return false;
            }

            // check if it matches
            if( (CurrentToken.Type == Token.EnumType.OPERATION) && (CurrentArc.Info == CurrentToken.ContentOperation) )
            {
               // if so, we call the Callback

               // execute delegate
               CallbackSuccess = false;
               CurrentArc.Callback(this, CurrentToken, CallbackSuccess, CallbackErrorMessage);

               if( !CallbackSuccess )
               {
                  // build complete error message
                  this.buildErrorMessage(ErrorMessage, false);
                  ErrorMessage ~= CallbackErrorMessage;
            
                  return false;
               }

               // we eat another token and we flush the expected stuff and we continue

               this.eatToken(CurrentToken, CalleeSuccess);
               if( !CalleeSuccess )
               {
                  ErrorMessage = "Internal Error!\n";
                  return false;
               }

               if( CurrentArc.Next.isNull() )
               {
                  ErrorMessage = "internal Error!\n";
                  return false;
               }

               StackContent.Index = CurrentArc.Next.Value;
               StackContent.Callback = &nothing;

               IndexStack.setTop(StackContent, Success);
               if( !Success )
               {
                  // Internal Error
                  ErrorMessage = "Internal Error!";
                  return false;
               }

               this.ExpectedOperations.length = 0;
               this.ExpectedKeyword.length = 0;
               this.ExpectedTokens.length = 0;

               continue;
            }

            this.ExpectedOperations ~= Token.OperationPlain[CurrentArc.Info];

            if( CurrentArc.Alternative.isNull() )
            {
               // build the error Message
               ErrorMessage = "";
               this.buildErrorMessage(ErrorMessage, true);

               return false;
            }

            // if we are here there are alternatives

            StackContent.Index = CurrentArc.Alternative.Value;
            StackContent.Callback = &nothing;

            IndexStack.setTop(StackContent, Success);
            if( !Success )
            {
               // Internal Error
               ErrorMessage = "Internal Error!";
               return false;
            }

            continue;
         }
         else if( CurrentArc.Type == Parser.Arc.EnumType.TOKEN )
         {
            // check for internal error token
            if( CurrentToken.Type == Token.EnumType.INTERNALERROR )
            {
               ErrorMessage = "Internal Error!";
               return false;
            }

            // check if the Token matches
            if( CurrentToken.Type == CurrentArc.Info )
            {
               // if so, we call the Callback
               CallbackSuccess = false;
               CurrentArc.Callback(this, CurrentToken, CallbackSuccess, CallbackErrorMessage);

               if( !CallbackSuccess )
               {
                  // build complete error message
                  this.buildErrorMessage(ErrorMessage, false);
                  ErrorMessage ~= CallbackErrorMessage;
                  
                  return false;
               }

               // we eat another token and we flush the expected stuff and we continue

               this.eatToken(CurrentToken, CalleeSuccess);
               if( !CalleeSuccess )
               {
                  ErrorMessage = "Internal Error!\n";
                  return false;
               }

               if( CurrentArc.Next.isNull() )
               {
                  ErrorMessage = "internal Error!\n";
                  return false;
               }

               StackContent.Index = CurrentArc.Next.Value;
               StackContent.Callback = &nothing;

               IndexStack.setTop(StackContent, Success);
               if( !Success )
               {
                  // Internal Error
                  ErrorMessage = "Internal Error!";
                  return false;
               }

               this.ExpectedOperations.length = 0;
               this.ExpectedKeyword.length = 0;
               this.ExpectedTokens.length = 0;

               continue;
            }

            ExpectedTokens ~= Token.TypeStrings[CurrentArc.Info];

            if( CurrentArc.Alternative.isNull() )
            {
               // build the error Message
               ErrorMessage = "";
               this.buildErrorMessage(ErrorMessage, true);

               return false;
            }

            // if we are here there are alternatives

            StackContent.Index = CurrentArc.Alternative.Value;
            StackContent.Callback = &nothing;

            IndexStack.setTop(StackContent, Success);
            if( !Success )
            {
               // Internal Error
               ErrorMessage = "Internal Error!";
               return false;
            }

            continue;
         }

         else if( CurrentArc.Type == Parser.Arc.EnumType.KEYWORD )
         {
            // check for internal error token
            if( CurrentToken.Type == Token.EnumType.INTERNALERROR )
            {
               ErrorMessage = "Internal Error!";
               return false;
            }

            // check if the Keyword matches
            if( (CurrentToken.Type == Token.EnumType.KEYWORD) && (CurrentToken.ContentKeyword == CurrentArc.Info) )
            {
               // if so, we call the Callback

               // execute delegate
               CallbackSuccess = false;
               CurrentArc.Callback(this, CurrentToken, CallbackSuccess, CallbackErrorMessage);

               if( !CallbackSuccess )
               {
                  // build complete error message
                  this.buildErrorMessage(ErrorMessage, false);
                  ErrorMessage ~= CallbackErrorMessage;
                  
                  return false;
               }

               // we eat another token and we flush the expected stuff and we continue

               this.eatToken(CurrentToken, CalleeSuccess);
               if( !CalleeSuccess )
               {
                  ErrorMessage = "Internal Error!\n";
                  return false;
               }

               if( CurrentArc.Next.isNull() )
               {
                  ErrorMessage = "internal Error!\n";
                  return false;
               }

               StackContent.Index = CurrentArc.Next.Value;
               StackContent.Callback = &nothing;

               IndexStack.setTop(StackContent, Success);
               if( !Success )
               {
                  // Internal Error
                  ErrorMessage = "Internal Error!";
                  return false;
               }

               this.ExpectedOperations.length = 0;
               this.ExpectedKeyword.length = 0;
               this.ExpectedTokens.length = 0;

               continue;
            }

            this.ExpectedKeyword ~= Token.KeywordString[CurrentArc.Info];

            if( CurrentArc.Alternative.isNull() )
            {
               // build the error Message
               ErrorMessage = "";
               this.buildErrorMessage(ErrorMessage, true);

               return false;
            }

            // if we are here there are alternatives

            StackContent.Index = CurrentArc.Alternative.Value;
            StackContent.Callback = &nothing;

            IndexStack.setTop(StackContent, Success);
            if( !Success )
            {
               // Internal Error
               ErrorMessage = "Internal Error!";
               return false;
            }

            continue;
         }
         else if( CurrentArc.Type == Parser.Arc.EnumType.END )
         {
            if( IndexStack.getCount() == 1)
            {
               break;
            }

            IndexStack.pop(StackContent, Success);
            if( !Success )
            {
               // Internal Error
               ErrorMessage = "Internal Error!";
               return false;
            }
         }

         else
         {
            ErrorMessage = "Internal Error!";
            return false;
         }
         
      }

      // check if the last token was an EOF
      if( CurrentToken.Type != Token.EnumType.EOF )
      {
         // TODO< add line information and marker >

         ErrorMessage = "Unexpected Tokens after . Token";
         return false;
      }

      return true;
   }

   // this gets the remaining tokens on the current line
   private bool getRemainingTokensOnLine()
   {
      Lexer.EnumLexerCode LexerReturnValue;
      Token CurrentToken;

      CurrentToken = new Token();

      for(;;)
      {
         uint TokensLength;

         LexerReturnValue = this.LexerObject.getNextToken(CurrentToken);

         if( LexerReturnValue == Lexer.EnumLexerCode.OK )
         {
         }
         else if( LexerReturnValue == Lexer.EnumLexerCode.INTERNALERROR )
         {
            // Internal Lexer error
            // TODO< emit return Value >
            return false;
         }
         else
         {
            // Internal error
            // TODO< emit error message >
            return false;
         }


         // check for EOF token
         if( CurrentToken.Type == Token.EnumType.EOF )
         {
            return true;
         }

         // check for INTERNALERROR Token
         if( CurrentToken.Type == Token.EnumType.INTERNALERROR )
         {
            return false;
         }

         TokensLength = this.Lines[this.Lines.length-1].Tokens.length;
         if( CurrentToken.Line != this.Lines[this.Lines.length-1].Tokens[TokensLength-1].Line ) // Correct?
         {
            return true;
         }
      }

      // NOTE< never reached >
      return true;
   }

   // this reads all tokens in TokensOnLine and reconstructs the text of that line
   // it also marks the token with the MarkerOffset
   private string buildTextWithMarker(uint MarkerOffset)
   {
      string Return;
      string LineContent;
      uint MarkerSpaceCount = 0;

      // TODO
      // TODO< exceptions >
      Return = "Line " ~ to!string(this.CurrentLineNumber) ~ ":" ~ "\n";

      foreach( Token CurrentToken; this.Lines[this.Lines.length-1].Tokens )
      {
         LineContent = leftJustify(LineContent, CurrentToken.Column);
         MarkerSpaceCount = LineContent.length;

         LineContent ~= CurrentToken.getRealString();
      }

      Return ~= LineContent ~ "\n";
      Return ~= leftJustify("", MarkerSpaceCount) ~ "^" ~ "\n";

      return Return;
   }

   private void eatToken(ref Token OutputToken, ref bool Success)
   {
      Lexer.EnumLexerCode LexerReturnValue;
      Token TempToken = new Token();

      LexerReturnValue = this.LexerObject.getNextToken(OutputToken);

      Success = (LexerReturnValue == Lexer.EnumLexerCode.OK);

      this.addTokenToLines(OutputToken.copy());

      //writeln("Parser::eatToken called, returned:");
      //OutputToken.debugIt();

      return;
   }

   private void buildErrorMessage(ref string ErrorMessage, bool AddExpected)
   {
      string enumerateStrings(string []Strings)
      {
         string Return = "";

         for(;;)
         {
            if( Strings.length == 0 )
            {
               return Return;
            }
            else if( Strings.length == 2 )
            {
               Return ~= Strings[0] ~ " or " ~ Strings[1];
               return Return;
            }
            else
            {
               Return ~= Strings[Strings.length-1] ~ ", ";
               Strings.length--;
            }
         }
      }

      uint CurrentTokenIndex;
      bool CalleeSuccess;

      CurrentTokenIndex = this.Lines[this.Lines.length-1].Tokens.length-1;

      CalleeSuccess = this.getRemainingTokensOnLine();

      if( !CalleeSuccess )
      {
         ErrorMessage = "Internal Error!";
         return;
      }

      ErrorMessage  ~= this.buildTextWithMarker(CurrentTokenIndex);
      
      if( AddExpected )
      {
         if( this.ExpectedKeyword.length == 1 )
         {
            ErrorMessage ~= "Keyword ";
         }
         else if( this.ExpectedKeyword.length > 1 )
         {
            ErrorMessage ~= "Keywords ";
         }

         if( this.ExpectedKeyword.length > 0 )
         {
            ErrorMessage ~= enumerateStrings(this.ExpectedKeyword) ~ " expected!\n";
         }


         if( this.ExpectedOperations.length == 1 )
         {
            ErrorMessage ~= "Operation ";
         }
         else if( this.ExpectedOperations.length > 1 )
         {
            ErrorMessage ~= "Operations ";
         }

         if( this.ExpectedOperations.length > 0 )
         {
            ErrorMessage ~= enumerateStrings(this.ExpectedOperations) ~ " expected!\n";
         }


         if( this.ExpectedTokens.length == 1 )
         {
            ErrorMessage ~= "Token ";
         }
         else if( this.ExpectedTokens.length > 1 )
         {
            ErrorMessage ~= "Tokens ";
         }
         if( this.ExpectedTokens.length > 0 )
         {
            ErrorMessage ~= enumerateStrings(this.ExpectedTokens) ~ " expected!\n";
         }
      }
   }

   public void setLexer(ref Lexer LexerObject0)
   {
      this.LexerObject = LexerObject0;
   }

   public void addTokenToLines(Token TokenObject)
   {
      if( TokenObject.Line != this.CurrentLineNumber )
      {
         CurrentLineNumber = TokenObject.Line;
         this.Lines ~= new Line();
      }

      this.Lines[this.Lines.length-1].Tokens ~= TokenObject;
   }

   private Arc []Arcs;
   public  Lexer LexerObject;

   //private Token []TokensOnLine;


   //private uint LineCounter = 0;

   // this is used for error messages
   private string []ExpectedOperations;
   private string []ExpectedKeyword;
   private string []ExpectedTokens;

   private Line []Lines;
   private uint CurrentLineNumber = 0;

   public NameListProcedure CurrentProcedure;
   private NameListProcedure RootProcedure;
   public uint ProcedureCounter = 1;

   public CodeGenerator CodeGen;


   // temporary values used for the semantic analysis
   public string TempIdentifier;

   public int []ConstContent;

   public void delegate(ref Parser ParserObj, ref Token CurrentToken, ref bool Success, ref string ErrorMessage) CallbackProcedureEnd;

   public enum EnumCondition
   {
      INVALID = 0, // should not appear

      EQUAL,
      NOTEQUAL,
      GREATER,
      GREATEREQUAL,
      LESS,
      LESSEQUAL
   }

   public EnumCondition ConditionType = EnumCondition.INVALID;
}
