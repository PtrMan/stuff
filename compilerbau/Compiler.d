import std.stdio : writeln;
import std.file : readText, FileException;

import Lexer : Lexer, Token;
import Parser : Parser;

void main(string[] Args)
{
   Lexer.EnumLexerCode LexerReturnCode;
   Token CurrentToken = new Token();
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

   CalleeSuccess = ParserObject.parse(ErrorMessage);
   
   if( !CalleeSuccess )
   {
      writeln(ErrorMessage);
   }
}
