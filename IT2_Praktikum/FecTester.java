
import java.io.*;
import java.util.*;
import java.util.Random;

public class FecTester
{
   //Video variables:
   //----------------
   int imagenb = 0;               // image nb of the image currently transmitted
   VideoStream video;             // VideoStream object used to access video frames
   
   static int MJPEG_TYPE = 26;    // RTP payload type for MJPEG video


   static int FRAME_PERIOD = 40;  // Frame period of the video to stream, in ms
   static int VIDEO_LENGTH = 500; // length of the video in frames
 
   byte[] buf = new byte[30000];// new byte[15000]; //buffer used to store the images to send to the client 

   RTPpacket LastRtpPacket = null;

   boolean FirstRtpPacket = true;

   public static void main(String Argv[]) throws Exception
   {
      // create a Server object
      FecTester theServer = new FecTester();

      // init the VideoStream object:
      theServer.video = new VideoStream("movie.mjpeg");

      theServer.test();
   }
   
   public void test() throws Exception
   {

      for(;;)
      {
      //if the current image nb is less than the length of the video
      if( imagenb < VIDEO_LENGTH )
      {
         //update current imagenb
         imagenb++;

            //get next frame to send from the video, as well as its size
            int image_length = video.getnextframe(buf);

            System.out.println(image_length);

            //Builds an RTPpacket object containing the frame
            RTPpacket rtp_packet = new RTPpacket(MJPEG_TYPE, imagenb, imagenb*FRAME_PERIOD, buf, image_length);

            if( this.FirstRtpPacket )
            {
               this.FirstRtpPacket = false;
            }
            else
            {
               // calculate and send FecPacket

               byte[] FecPacketContent = RTPpacket.buildFecPacket(this.LastRtpPacket, rtp_packet, 0 /* TODO */, rtp_packet.TimeStamp);

               // selftest
               System.out.println("B and FEC");
               FecPacket TestFecPacket = FecPacket.deSerilize(FecPacketContent, FecPacketContent.length);

               RTPpacket ReconstructedRtp = FecPacket.reconstruct(TestFecPacket, rtp_packet);
               byte[] ReconstructedRtpBytes = ReconstructedRtp.getComplete();

               for( int i = 0; i < ReconstructedRtpBytes.length; i++ )
               {
               }
               
               byte[] OrginalRtpBytes = this.LastRtpPacket.getComplete();
               
               if( ReconstructedRtpBytes.length != OrginalRtpBytes.length )
               {
                  System.out.println("unequal size!");
                  System.exit(0);
               }

               for( int i = 0; i < OrginalRtpBytes.length; i++ )
               {
                  if( OrginalRtpBytes[i] != ReconstructedRtpBytes[i] )
                  {

                     System.out.print("mismatch at ");
                     System.out.print(i);
                     System.out.println(" !");

                     this.debugArray(OrginalRtpBytes);
                     System.out.println("---");
                     this.debugArray(ReconstructedRtpBytes);

                     System.exit(0);
                  }
               }
               System.out.print("all ok\n");


               System.out.println("A and FEC");

               ReconstructedRtp = FecPacket.reconstruct(TestFecPacket, this.LastRtpPacket);
               ReconstructedRtpBytes = ReconstructedRtp.getComplete();

               for( int i = 0; i < ReconstructedRtpBytes.length; i++ )
               {
               }
               
               OrginalRtpBytes = rtp_packet.getComplete();
               
               if( ReconstructedRtpBytes.length != OrginalRtpBytes.length )
               {
                  System.out.println("unequal size!");
                  
                  System.out.print("Size Reconstructed ");
                  System.out.println(ReconstructedRtpBytes.length);

                  System.out.print("Size orginal ");
                  System.out.println(OrginalRtpBytes.length);

                  System.exit(0);
               }

               for( int i = 0; i < OrginalRtpBytes.length; i++ )
               {
                  if( OrginalRtpBytes[i] != ReconstructedRtpBytes[i] )
                  {
                     System.out.println(i);

                     System.out.println("mismatch!");

                     this.debugArray(OrginalRtpBytes);
                     System.out.println("---");
                     this.debugArray(ReconstructedRtpBytes);

                     System.exit(0);
                  }
               }
               System.out.print("all ok\n");
            

            
            }
            
            this.LastRtpPacket = rtp_packet;
      }
      else
      {
         break;
      }
   }
   }

   private void debugArray(byte[] Data)
   {
      int i;

      for( i=0; i < Data.length; i++ )
      {
         System.out.print(Data[i]);
         System.out.print(" ");

         if( i!=0 && (i % 16) == 0 )
         {
            System.out.print("\n");
         }
      }
   }
}
