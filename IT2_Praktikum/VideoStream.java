//VideoStream

import java.io.*;

public class VideoStream
{
   private FileInputStream fis; // video file
   private int frameNumber;     // current Frame number

   //-----------------------------------
   //constructor
   //-----------------------------------
   public VideoStream(String filename) throws Exception
   {
      // init variables
      this.fis = new FileInputStream(filename);
      this.frameNumber = 0;
   }

   // returns the next frame as an array of byte and the size of the frame
   public int getnextframe(byte[] Frame) throws Exception
   {
      int length = 0;
      String length_string;
      byte[] frame_length = new byte[5];

      //read current frame length
      this.fis.read(frame_length, 0, 5);

      //transform frame_length to integer
      length_string = new String(frame_length);
      length = Integer.parseInt(length_string);

      return this.fis.read(Frame, 0, length);
   }
}
