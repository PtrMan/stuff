import std.stdio : writeln;
import std.file : readText, FileException;

import Lexer : Lexer, Token;
import Parser : Parser;

void main(string[] Args)
{
   Parser ParserObject;
   Lexer L;
   string ErrorMessage;
   bool CalleeSuccess;
   
   string Content;

   L = new Lexer();
   ParserObject = new Parser();
   ParserObject.setLexer(L);
   
   if( Args.length != 2)
   {
      writeln("Ungultige Parameteranzahl!");
      return;
   }
   
   try
   {
      Content = readText(Args[1]);
   }
   catch( FileException E )
   {
      writeln("Konnte Datei ", Args[1], " nicht oeffnen!");
      return;
   }

   L.setSource(Content);

   // TODO< output tokens >
   /*
   Token CurrentToken = new Token();
   for(;;)
   {
      Lexer.EnumLexerCode LexerCode = L.getNextToken(CurrentToken);

      if( LexerCode != Lexer.EnumLexerCode.OK )
      {
         writeln("lexing failed!");
         return;
      }

      CurrentToken.debugIt();

      if( CurrentToken.Type == Token.EnumType.EOF )
      {
         break;
      }
   }
   
   return;
   */

   CalleeSuccess = ParserObject.parse(ErrorMessage);
   
   if( !CalleeSuccess )
   {
      writeln("Error:");
      writeln(ErrorMessage);
   }
}
