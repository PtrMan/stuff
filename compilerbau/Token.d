import std.stdio : writeln;

// exceptions?
import std.conv : to;

class Token
{
   public enum EnumType
   {
      NUMBER = 0,
      IDENTIFIER,
      KEYWORD,       // example: if do end then
      OPERATION,     // example: := > < >= <=
      
      ERROR,         // if Lexer found an error
      INTERNALERROR, // if token didn't got initialized by Lexer
      STRING,        // "..."
      
      EOF            // end of file
      // TODO< more? >
   }
   
   public static const string[] TypeStrings = ["NUMBER", "IDENTIFIER", "KEYWORD", "OPERATION", "ERROR", "INTERNALERROR", "STRING", "EOF"]; 

   public enum EnumOperation
   {
      PLUS = 0,
      MINUS,
      MUL,
      DIV,

      SEMICOLON,    // ;
      COMMA,        // ,
      
      OUTPUT,       // !
      INPUT,        // ?

      POINT,        // .
      EQUAL,        // =

      BRACEOPEN,    // (
      BRACECLOSE,   // )
   
      UNEQUAL,      // #

      ASSIGNMENT,   // :=
      GREATER,      // >
      SMALLER,      // <

      GREATEREQUAL, // >=
      SMALLEREQUAL, // <=
      
      INTERNALERROR
   }
   
   private static const string[] OperationString = [
      "PLUS", "MINUS", "MUL", "DIV", "SEMICOLON", "COMMA", "OUTPUT", "INPUT", "POINT", "EQUAL",

      "BRACEOPEN", "BRACECLOSE",

      "UNEQUAL",

      "ASSIGNMENT", "GREATER", "SMALLER",
      "GREATEREQUAL", "SMALLEREQUAL",

      "INTERNALERROR"];

   public static const string[] OperationPlain = [
      "+", "-", "*", "/", ";", ",", "!", "?", ".", "=", "(", ")", "#", ":=", ">", "<", ">=", "<="
   ];

   public enum EnumKeyword
   {
      BEGIN = 0,
      CALL,
      CONST,
      DO,
      ELSE,
      END,
      GET,
      IF,
      ODD,
      PROCEDURE,
      PUT,
      THEN,
      VAR,
      WHILE
   }

   public static const string[] KeywordString = [
      "begin", "call", "const", "do", "else", "end", "get", "if", "odd", "procedure", "put", "then", "var", "while"
   ];

   public void debugIt()
   {
      writeln("Type: " ~ TypeStrings[this.Type]);

      if( this.Type == EnumType.OPERATION )
      {
         writeln("Operation: " ~ OperationString[this.ContentOperation]);
      }
      else if( this.Type == EnumType.NUMBER )
      {
         writeln(this.ContentNumber);
      }
      else if( this.Type == EnumType.KEYWORD )
      {
         writeln(KeywordString[this.ContentKeyword]);
      }
      else if( (this.Type == EnumType.IDENTIFIER) || (this.Type == EnumType.STRING) )
      {
         writeln(this.ContentString);
      }

      writeln("Line   : ", this.Line);
      writeln("Column : ", this.Column);

      writeln("===");
   }

   public string getRealString()
   {
      if( this.Type == EnumType.OPERATION )
      {
         return OperationPlain[this.ContentOperation];
      }
      else if( (this.Type == EnumType.IDENTIFIER) || (this.Type == EnumType.STRING) )
      {
         return this.ContentString;
      }
      else if( this.Type == EnumType.NUMBER )
      {
         // TODO< catch exceptions >
         return to!string(ContentNumber);
      }
      else if( this.Type == EnumType.KEYWORD )
      {
         return KeywordString[this.ContentKeyword];
      }
      

      return "";
   }

   public Token copy()
   {
      Token Return;

      Return = new Token();
      Return.ContentString = this.ContentString;
      Return.ContentOperation = this.ContentOperation;
      Return.ContentNumber = this.ContentNumber;
      Return.ContentKeyword = this.ContentKeyword;
      Return.Type = this.Type;
      Return.Line = this.Line;
      Return.Column = this.Column;
      
      return Return;
   }

   public string ContentString;
   public EnumOperation ContentOperation = EnumOperation.INTERNALERROR;
   public int ContentNumber = 0;
   public EnumKeyword ContentKeyword;

   public EnumType Type = EnumType.INTERNALERROR;
   public uint Line = 0;
   public uint Column = 0; // Spalte
   // public string Filename;
   
}