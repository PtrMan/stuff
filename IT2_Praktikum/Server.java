
/* ------------------
   Server
   usage: java Server [RTSP listening port]
   ---------------------- */


import java.io.*;
import java.net.*;
import java.awt.*;
import java.util.*;
import java.awt.event.*;
import javax.swing.*;
import javax.swing.Timer;
import java.util.Random;

public class Server extends JFrame implements ActionListener
{

   //RTP variables:
   //----------------
   DatagramSocket RTPsocket; //socket to be used to send and receive UDP packets
   DatagramPacket senddp; //UDP packet containing the video frames
 
   InetAddress ClientIPAddr; //Client IP address
   int RTP_dest_port = 0; // destination port for RTP packets  (given by the RTSP Client)
  
   //GUI:
   //----------------
   JLabel label;
   JTextField GuiLostRateText; // Textfield for the Lostrate

   //Video variables:
   //----------------
   int imagenb = 0;               // image nb of the image currently transmitted
   VideoStream video;             // VideoStream object used to access video frames
   
   static int MJPEG_TYPE = 26;    // RTP payload type for MJPEG video


   static int FRAME_PERIOD = 40;  // Frame period of the video to stream, in ms
   static int VIDEO_LENGTH = 500; // length of the video in frames
 
   Timer timer; //timer used to send the images at the video frame rate
   byte[] buf = new byte[30000];// new byte[15000]; //buffer used to store the images to send to the client 

   //RTSP variables
   //----------------
   //rtsp states
   final static int INIT = 0;
   final static int READY = 1;
   final static int PLAYING = 2;
   //rtsp message types
   final static int SETUP = 3;
   final static int PLAY = 4;
   final static int PAUSE = 5;
   final static int TEARDOWN = 6;
   final static int OPTIONS = 7;

   static int state; //RTSP Server state == INIT or READY or PLAY
   Socket RTSPsocket; //socket used to send/receive RTSP messages
   //input and output stream filters
   static BufferedReader RTSPBufferedReader;
   static BufferedWriter RTSPBufferedWriter;
   static String VideoFileName; //video file requested from the client
   static int RTSP_ID = 123456; //ID of the RTSP session
   int RTSPSeqNb = 0; //Sequence number of RTSP messages within the session
  
   final static String CRLF = "\r\n";

   private float LostRate;
   private Random Rand = new Random();

   RTPpacket LastRtpPacket = null;

   boolean FirstRtpPacket = true;

   //--------------------------------
   //Constructor
   //--------------------------------
   public Server()
   {
      // init Frame
      super("Server");

      //init Timer
      timer = new Timer(FRAME_PERIOD, this);
      timer.setInitialDelay(0);
      timer.setCoalesce(true);

      //allocate memory for the sending buffer
      //this.buf = new byte[30000];// new byte[15000]; 

      //Handler to close the main window
      addWindowListener(
         new WindowAdapter()
         {
            public void windowClosing(WindowEvent e)
            {
               //stop the timer and exit
               timer.stop();
               System.exit(0);
            }
         }
      );

      //GUI:
      this.label = new JLabel("Send frame #        ", JLabel.CENTER);
      this.getContentPane().add(this.label, BorderLayout.CENTER);

      this.GuiLostRateText = new JTextField();
      this.GuiLostRateText.setText("0.0");
      this.getContentPane().add(this.GuiLostRateText, BorderLayout.SOUTH);
   }

   public static void main(String Argv[]) throws Exception
   {
      //create a Server object
      Server theServer = new Server();

      //show GUI:
      theServer.pack();
      theServer.setVisible(true);

      if( Argv.length != 1 )
      {
         System.out.println("Wrong count of arguments!");
         return;
      }

      //get RTSP socket port from the command line
      int RTSPport = Integer.parseInt(Argv[0]);
   
      //Initiate TCP connection with the client for the RTSP session
      ServerSocket listenSocket = new ServerSocket(RTSPport);
      theServer.RTSPsocket = listenSocket.accept();
      listenSocket.close();

      //Get Client IP address
      theServer.ClientIPAddr = theServer.RTSPsocket.getInetAddress();

      //Initiate RTSPstate
      state = INIT;

      //Set input and output stream filters:
      RTSPBufferedReader = new BufferedReader(new InputStreamReader(theServer.RTSPsocket.getInputStream()) );
      RTSPBufferedWriter = new BufferedWriter(new OutputStreamWriter(theServer.RTSPsocket.getOutputStream()) );

      //Wait for the SETUP message from the client
      int requestType;
      boolean done = false;
      
      for(;;)
      {
         requestType = theServer.parse_RTSP_request(); // blocking
         
         if( requestType == SETUP )
         {
            
            // update RTSP state
            state = READY;
            System.out.println("New RTSP state: READY");
   
            // Send response
            theServer.sendRtspResponse(false);

            System.out.println("VideoFileName " + VideoFileName);
   
            // init the VideoStream object:
            theServer.video = new VideoStream(VideoFileName);

            // init RTP socket
            theServer.RTPsocket = new DatagramSocket();

            break;
         }
         else if( requestType == OPTIONS )
         {
            System.out.println("OPTIONS detected!");

            // send back response
            theServer.sendRtspResponse(true);
         }
      }

      //loop to handle RTSP requests
      while(true)
      {
         // parse the request
         requestType = theServer.parse_RTSP_request(); // blocking
         

         if( (requestType == PLAY) && (state == READY) )
         {
            // send back response
            theServer.sendRtspResponse(false);
            // start timer
            theServer.timer.start();
            // update state
            state = PLAYING;
            System.out.println("New RTSP state: PLAYING");
         }
         else if( (requestType == PAUSE) && (state == PLAYING) )
         {
            // send back response
            theServer.sendRtspResponse(false);
            // stop timer
            theServer.timer.stop();
            // update state
            state = READY;
            System.out.println("New RTSP state: READY");
         }
         else if( requestType == TEARDOWN )
         {
            // send back response
            theServer.sendRtspResponse(false);
            // stop timer
            theServer.timer.stop();
            // close sockets
            theServer.RTSPsocket.close();
            theServer.RTPsocket.close();

            System.exit(0);
         }
         else if( requestType == OPTIONS )
         {
            System.out.println("OPTIONS detected!");

            // send back response
            theServer.sendRtspResponse(true);
         }
      }
   }


   //------------------------
   //Handler for timer
   //------------------------
   public void actionPerformed(ActionEvent e)
   {
      String StringLostRate;
      
      StringLostRate = this.GuiLostRateText.getText();

      try
      {
         this.LostRate = Float.parseFloat(StringLostRate);
      }
      catch( NumberFormatException e0 )
      {
      }
      
      //if the current image nb is less than the length of the video
      if( imagenb < VIDEO_LENGTH )
      {
         //update current imagenb
         imagenb++;
         
         try
         {
            //get next frame to send from the video, as well as its size
            int image_length = video.getnextframe(buf);

            System.out.println(image_length);

            //Builds an RTPpacket object containing the frame
            RTPpacket rtp_packet = new RTPpacket(MJPEG_TYPE, imagenb, imagenb*FRAME_PERIOD, buf, image_length);

            for( int i = 0; i < 5; i++ )
            {
               System.out.println("");
            }

            //System.out.print("Payload dump for SequenceNumber ");
            //System.out.println(rtp_packet.SequenceNumber);
            //System.out.print(rtp_packet.dumpPayloadBinary());

            if( this.FirstRtpPacket )
            {
               this.FirstRtpPacket = false;
            }
            else
            {
               // calculate and send FecPacket

               byte[] FecPacketContent = RTPpacket.buildFecPacket(this.LastRtpPacket, rtp_packet, 0 /* TODO */, rtp_packet.TimeStamp);

               FecPacket TestFecPacket = FecPacket.deSerilize(FecPacketContent, FecPacketContent.length);
               /*               
               RTPpacket ReconstructedRtp = FecPacket.reconstruct(TestFecPacket, rtp_packet);
               byte[] ReconstructedRtpBytes = ReconstructedRtp.getComplete();

               for( int i = 0; i < ReconstructedRtpBytes.length; i++ )
               {
               }
               System.out.print("\n");

               byte[] OrginalRtpBytes = this.LastRtpPacket.getComplete();
               
               if( ReconstructedRtpBytes.length != OrginalRtpBytes.length )
               {
                  System.out.println("unequal size!");
                  System.exit(0);
               }

               for( int i = 0; i < OrginalRtpBytes.length; i++ )
               {
                  System.out.print(ReconstructedRtpBytes[i]);
                  System.out.print(" ");
                  System.out.print(OrginalRtpBytes[i]);
                  System.out.print("\n");

                  if( OrginalRtpBytes[i] != ReconstructedRtpBytes[i] )
                  {
                     System.out.println(i);

                     System.out.println("mismatch!");
                     System.exit(0);
                  }
               }
               System.out.print("all ok\n");

               System.exit(0);
               */

               //System.out.print("Send FEC with sn-base ");
               //System.out.println(TestFecPacket.SnBase);

               // send the packet as a DatagramPacket over the UDP socket 
               // senddp = new DatagramPacket(packet_bits, packet_length, ClientIPAddr, RTP_dest_port);
               
               if( this.Rand.nextInt(100) > (int)(this.LostRate*100.0f) )
               {
                  senddp = new DatagramPacket(FecPacketContent, FecPacketContent.length, ClientIPAddr, RTP_dest_port);

                  RTPsocket.send(senddp);
               }

            }

            this.LastRtpPacket = rtp_packet;
	  

            if( this.Rand.nextInt(100) > (int)(this.LostRate*100.0f) )
            {
               // get to total length of the full rtp packet to send
               int packet_length = rtp_packet.getlength();

               // retrieve the packet bitstream and store it in an array of bytes
               // byte[] packet_bits = new byte[packet_length];
               // rtp_packet.getpacket(packet_bits);
               rtp_packet.getpacket(buf);

               
               
               // send the packet as a DatagramPacket over the UDP socket 
               // senddp = new DatagramPacket(packet_bits, packet_length, ClientIPAddr, RTP_dest_port);
               senddp = new DatagramPacket(buf, packet_length, ClientIPAddr, RTP_dest_port);
            

               RTPsocket.send(senddp);

               //System.out.println("Send frame #"+imagenb);
               //print the header bitstream
               rtp_packet.printheader();

               //update GUI
               label.setText("Send frame #" + imagenb);
            }
         }
         catch(Exception ex)
         {
            System.out.println("Exception caught: "+ex);
            System.exit(0);
         }
      }
      else
      {
         //if we have reached the end of the video file, stop the timer
         timer.stop();
      }
   }

   //------------------------------------
   //Parse RTSP Request
   //------------------------------------
   private int parse_RTSP_request()
   {
      int RequestType;

      RequestType = -1;

      try
      {
         // parse request line and extract the request_type
         String RequestLine = this.RTSPBufferedReader.readLine();
         
         System.out.println("RTSP Server - Received from Client:");
         System.out.println(RequestLine);

         //String request_type_string = tokens.nextToken();

         String []Tokens = RequestLine.split("\\s+");

         if( Tokens.length < 1 )
         {
            System.out.println("Error: RTSP request is invalid!");
            System.exit(1);
         }

         String RequestTypeString = Tokens[0];

         System.out.println(RequestTypeString + "+");

         //convert to request_type structure:
         if( RequestTypeString.compareTo("SETUP") == 0 )
         {
            RequestType = SETUP;
         }
         else if( RequestTypeString.compareTo("PLAY") == 0 )
         {
            RequestType = PLAY;
         }
         else if( RequestTypeString.compareTo("PAUSE") == 0 )
         {
            RequestType = PAUSE;
         }
         else if( RequestTypeString.compareTo("TEARDOWN") == 0 )
         {
            RequestType = TEARDOWN;
         }
         else if( RequestTypeString.compareTo("OPTIONS") == 0 )
         {
            RequestType = OPTIONS;
         }

         if (RequestType == SETUP)
         {
            if( Tokens.length < 2 )
            {
               System.out.println("Error: RTSP request is invalid!");
               System.exit(1);
            }

            // extract VideoFileName from RequestLine
            VideoFileName = Tokens[1];
         }

         //parse the SeqNumLine and extract CSeq field


         StringTokenizer tokens; // from professor

         String SeqNumLine = RTSPBufferedReader.readLine();
         System.out.println(SeqNumLine);
         tokens = new StringTokenizer(SeqNumLine);
         tokens.nextToken();
         RTSPSeqNb = Integer.parseInt(tokens.nextToken());

         //get LastLine
         String LastLine = RTSPBufferedReader.readLine();
         System.out.println(LastLine);

         if (RequestType == SETUP)
         {
            //extract RTP_dest_port from LastLine
            tokens = new StringTokenizer(LastLine);
            for (int i=0; i<3; i++)
            {
               tokens.nextToken(); //skip unused stuff
            }

            RTP_dest_port = Integer.parseInt(tokens.nextToken());
         }
         //else LastLine will be the SessionId line ... do not check for now.
      }
      catch(Exception ex)
      {
         System.out.println("Exception caught: "+ex);
         System.exit(0);
      }

      return RequestType;
   }

   //------------------------------------
   //Send RTSP Response
   //------------------------------------
   private void sendRtspResponse(boolean Options)
   {
      try
      {
         if( Options )
         {
            System.out.println("send OPTIONS response");

            RTSPBufferedWriter.write("RTSP/1.0 200 OK" + CRLF);
            RTSPBufferedWriter.write("CSeq: " + RTSPSeqNb + CRLF);
            RTSPBufferedWriter.write("Public: " + "SETUP, PLAY, PAUSE, TEARDOWN" + CRLF);
         }
         else
         {
            RTSPBufferedWriter.write("RTSP/1.0 200 OK" + CRLF);
            RTSPBufferedWriter.write("CSeq: " + RTSPSeqNb + CRLF);
            RTSPBufferedWriter.write("Session: " + RTSP_ID + CRLF);
            
            //System.out.println("RTSP Server - Sent response to Client.");
         }
         RTSPBufferedWriter.flush();
      }
      catch( Exception ex )
      {
	      System.out.println("Exception caught: "+ex);
	      System.exit(0);
      }
   }
}
