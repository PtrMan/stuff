import java.io.*;

class Logger
{
   private FileWriter FileWriterObj;
   private PrintWriter PrintWriterObj;

   public boolean openLog(String Filename)
   {
      try
      {
         this.FileWriterObj = new FileWriter(Filename);
         this.PrintWriterObj = new PrintWriter(this.FileWriterObj);
      }
      catch( IOException e )
      {
         return false;
      }

      return true;
   }

   public void writeString(String Text)
   {
      this.PrintWriterObj.println(Text);
      this.PrintWriterObj.flush();
   }

   // TODO close with this.PrintWriterObj.close()
}
