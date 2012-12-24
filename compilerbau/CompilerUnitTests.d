import std.stdio : writeln;
import std.file : readText, FileException;

import Lexer : Lexer, Token;
import Parser : Parser;

// test case for the parser

void main(string[] Args)
{
   Lexer.EnumLexerCode LexerReturnCode;
   Token CurrentToken = new Token();
   Parser ParserObject;
   Lexer L;
   string ErrorMessage;
   bool CalleeSuccess;

   string []Positives;
   string []Negatives;

   L = new Lexer();
   ParserObject = new Parser();
   ParserObject.setLexer(L);
   
   if( Args.length != 1)
   {
      writeln("Ungultige Parameteranzahl!");
      return;
   }

   // test cases for parsing only

   Negatives ~= "a := b := c.";
   Negatives ~= "var a a.";
   Negatives ~= "var a := b.";
   Negatives ~= "if a := b then b := c.";
   Negatives ~= "procedure x; y y.";
   Negatives ~= "procedure x; x = y.";
   Negatives ~= "procedure if; a := b.";
   Negatives ~= "const a =.";
   Negatives ~= "const a = b.";
   Negatives ~= "const a = b; b = c.";
   Negatives ~= "const a = b,";
   Negatives ~= "var a;a.";
   Negatives ~= "var a,n.";
   Negatives ~= "var x; const a = 5;."; // invalid order
   Negatives ~= "..";
   Negatives ~= "a := --5.";
   Negatives ~= "a := 5 + + 7.";
   Negatives ~= "a:=5 * * 6.";
   Negatives ~= "a:=6 * +5."; // is in c valid
   Negatives ~= "if 1 then a := b."; // is in c valid
   Negatives ~= "call 5.";
   Negatives ~= "?.";


   Positives ~= ".";
   Positives ~= "const a = 5;.";
   Positives ~= "const a = 5, b = 6;.";
   Positives ~= "const a = 5, b = 6; var r;.";
   Positives ~= "const a = 5; var b; a := 5.";
   Positives ~= "const a = 5; var b; a := b.";
   Positives ~= "const a = 5; var b; a := -5.";
   Positives ~= "const a = 5; var b; a := -5 + z * u / 5 * (h - j)."; // test all? mathematical stuff
   Positives ~= "if odd x then a := 5."; // test if and condition
   Positives ~= "if r = r then a := 5."; // -'-
   Positives ~= "if r # r then a := 5."; // -'-
   Positives ~= "if r < r then a := 5."; // -'-
   Positives ~= "if r <= r then a := 5."; // -'-
   Positives ~= "if r > r then a := 5."; // -'-
   Positives ~= "if r >= r then a := 5."; // -'-

   Positives ~= "while 5 > 4 do a := b.";
   Positives ~= "begin a:= b; c := d end.";
   Positives ~= "call x.";
   Positives ~= "?r.";
   Positives ~= "!g + 6.";


   // go through all negatives
   writeln("Negatives:");

   foreach( string CurrentString; Negatives )
   {
      writeln("Negative '", CurrentString, "'");

      L.setSource(CurrentString);

      CalleeSuccess = ParserObject.parse(ErrorMessage);
   
      if( CalleeSuccess )
      {
         writeln("Negative Example '", CurrentString , "' didn't fail!");
         return;
      }
   }

   // go through all positives
   writeln("Positives:");

   foreach( string CurrentString; Positives )
   {
      writeln("Positive '", CurrentString, "'");

      L.setSource(CurrentString);

      CalleeSuccess = ParserObject.parse(ErrorMessage);
   
      if( !CalleeSuccess )
      {
         writeln("Positive Example '", CurrentString , "' did fail!");
         return;
      }
   }

   writeln("Done");
}
