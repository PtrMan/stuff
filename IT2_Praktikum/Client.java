
/* ------------------
   Client
   usage: java Client [Server hostname] [Server RTSP listening port] [Video file requested]
   ---------------------- */

import java.io.*;
import java.net.*;
import java.util.*;
import java.awt.*;
import java.awt.event.*;
import javax.swing.*;
import javax.swing.Timer;

public class Client
{

   //GUI
   //----
   JFrame f = new JFrame("Client");
   JButton setupButton = new JButton("Setup");
   JButton playButton = new JButton("Play");
   JButton pauseButton = new JButton("Pause");
   JButton tearButton = new JButton("Teardown");
   JPanel mainPanel = new JPanel();
   JPanel buttonPanel = new JPanel();
   JLabel iconLabel = new JLabel();
   ImageIcon icon;
 
 
   //RTP variables:
   //----------------
   DatagramPacket rcvdp; //UDP packet received from the server
   DatagramSocket RTPsocket; //socket to be used to send and receive UDP packets
   static int RTP_RCV_PORT = 25000; //port where the client will receive the RTP packets
   
   Timer timer; //timer used to receive data from the UDP socket
   byte[] buf; //buffer used to store data received from the server 
  
   //RTSP variables
   //----------------
   //rtsp states 
   final static int INIT = 0;
   final static int READY = 1;
   final static int PLAYING = 2;
   static int state; //RTSP state == INIT or READY or PLAYING
   Socket RTSPsocket; //socket used to send/receive RTSP messages
   //input and output stream filters
   static BufferedReader RTSPBufferedReader;
   static BufferedWriter RTSPBufferedWriter;
   static String VideoFileName; //video file to request to the server
   int RTSPSeqNb = 0; //Sequence number of RTSP messages within the session
   int RTSPid = 0; //ID of the RTSP session (given by the RTSP Server)

   final static String CRLF = "\r\n";

   //Video constants:
   //------------------
   static int MJPEG_TYPE = 26; //RTP payload type for MJPEG video

   ArrayList PacketList = new ArrayList();

   ArrayList FecPacketList = new ArrayList();

   // list with corrected packets
   ArrayList CorrectedPacketList = new ArrayList();

   // state of streaming
   // 0 : prebuffering
   // 1 : playing
   int StreamState = 0;

   // current Playing time
   // outdated
   int CurrentPlayingTime = 0;

   int CurrentPlaySequenceNumber = 0;
   int CurrentFecSeqenceNumber = 0;
   boolean FecReceivedFromServer = false; // were in pre buffering fec packets received?

   // statistics
   int ReceivedPackets = 0; // Count of Received packets
   int MaxSequenceNumber = 0; // highes packet number / sequence number
   int Datarate = 0;

   int TimerMiliseconds = 0;


   public Client()
   {

      
   }

   public static void main(String Arguments[]) throws Exception
   {
      InetAddress ServerIPAddr;

      // Create a Client object
      Client theClient = new Client();

      if( Arguments.length != 3 )
      {
         System.out.println("Invalid Arguments!");
         System.out.println("Usage: java Client [Server hostname] [Server RTSP listening port] [Video file requested]");
         return;
      }

      // get server RTSP port and IP address from the command line
      //------------------
      int RTSP_server_port = Integer.parseInt(Arguments[1]);
      String ServerHost = Arguments[0];

      try
      {
         ServerIPAddr = InetAddress.getByName(ServerHost);
      }
      catch( java.net.UnknownHostException E )
      {
         System.out.println("Error: Host " + ServerHost + " was not found!");
         return;
      }

      // get video filename to request:
      VideoFileName = Arguments[2];

      // Establish a TCP connection with the server to exchange RTSP messages
      try
      {
         theClient.RTSPsocket = new Socket(ServerIPAddr, RTSP_server_port);
      }
      catch( java.net.ConnectException E )
      {
         System.out.println("Error: Connection to Host " + ServerHost + " couldn't be established!");
         return;
      }

      // Set input and output stream filters:
      RTSPBufferedReader = new BufferedReader(new InputStreamReader(theClient.RTSPsocket.getInputStream()) );
      RTSPBufferedWriter = new BufferedWriter(new OutputStreamWriter(theClient.RTSPsocket.getOutputStream()) );
  
      // init RTSP state:
      state = INIT;

      theClient.init();
   }


   void init()
   {
      //build GUI
      //--------------------------

      // Frame
      f.addWindowListener(new WindowAdapter()
      {
         public void windowClosing(WindowEvent e)
         {
            System.exit(0);
         }
      }
      );

      // Buttons
      buttonPanel.setLayout(new GridLayout(1,0));
      buttonPanel.add(setupButton);
      buttonPanel.add(playButton);
      buttonPanel.add(pauseButton);
      buttonPanel.add(tearButton);
      setupButton.addActionListener(new setupButtonListener());
      playButton.addActionListener(new playButtonListener());
      pauseButton.addActionListener(new pauseButtonListener());
      tearButton.addActionListener(new tearButtonListener());

      // Image display label
      iconLabel.setIcon(null);
    
      // frame layout
      mainPanel.setLayout(null);
      mainPanel.add(iconLabel);
      mainPanel.add(buttonPanel);
      iconLabel.setBounds(0,0,380,280);
      buttonPanel.setBounds(0,280,380,50);

      f.getContentPane().add(mainPanel, BorderLayout.CENTER);
      f.setSize(new Dimension(390,370));
      f.setVisible(true);

      // allocate enough memory for the buffer used to receive data from the server
      buf = new byte[15000];

      // init timer
      timer = new Timer(20, new TimerListener(this));
      timer.setInitialDelay(0);
      timer.setCoalesce(true);
   }

   //------------------------------------
   //Handler for buttons
   //------------------------------------

   //Handler for Setup button
   //-----------------------
   class setupButtonListener implements ActionListener
   {
      public void actionPerformed(ActionEvent e)
      {
   
         //System.out.println("Setup Button pressed !");      
   
         if (state == INIT) 
         {
            //Init non-blocking RTPsocket that will be used to receive data
            try
            {
               //construct a new DatagramSocket to receive RTP packets from the server, on port RTP_RCV_PORT
               RTPsocket = new DatagramSocket(RTP_RCV_PORT);

               //set TimeOut value of the socket to 5msec.
               RTPsocket.setSoTimeout(5);
            }
            catch( SocketException se )
            {
               System.out.println("Socket exception: "+se);
               System.exit(0);
            }

            //init RTSP sequence number
            RTSPSeqNb = 1;
           
            //Send SETUP message to the server
            send_RTSP_request("SETUP");
            //Wait for the response 
            if( parse_server_response() != 200 )
            {
               System.out.println("Invalid Server Response");
            }
            else 
            {
               //change RTSP state and print new state 
               state = READY;
               System.out.println("New RTSP state: READY");
            }
         }
      }
   }

   //Handler for Play button
   //-----------------------
   class playButtonListener implements ActionListener
   {
      public void actionPerformed(ActionEvent e)
      {
         System.out.println("Play Button pressed !"); 
         
         if( state == READY ) 
         {
            //increase RTSP sequence number
            RTSPSeqNb++; // right?

            //Send PLAY message to the server
            send_RTSP_request("PLAY");

            //Wait for the response 
            if (parse_server_response() != 200)
            {
               System.out.println("Invalid Server Response");
            }
            else
            {
               //change RTSP state and print out new state
               state = PLAYING;
               System.out.println("New RTSP state: PLAY");
               
               //start the timer
               timer.start();
            }
         }//else if state != READY then do nothing
      }
   }


   //Handler for Pause button
   //-----------------------
   class pauseButtonListener implements ActionListener
   {
      public void actionPerformed(ActionEvent e)
      {
         //System.out.println("Pause Button pressed !");   

         if( state == PLAYING ) 
         {
            //increase RTSP sequence number
            RTSPSeqNb++; // right?

            //Send PAUSE message to the server
            send_RTSP_request("PAUSE");

            //Wait for the response 
            if (parse_server_response() != 200)
            {
               System.out.println("Invalid Server Response");
            }
            else 
            {
               //change RTSP state and print out new state
               state = READY;
               System.out.println("New RTSP state: READY");
            
               //stop the timer
               timer.stop();
            }
         }
         //else if state != PLAYING then do nothing
      }
   }

   //Handler for Teardown button
   //-----------------------
   class tearButtonListener implements ActionListener
   {
      public void actionPerformed(ActionEvent e)
      {

         System.out.println("Teardown Button pressed !");  

         //increase RTSP sequence number
         RTSPSeqNb++; // right?

         //Send TEARDOWN message to the server
         send_RTSP_request("TEARDOWN");

         //Wait for the response 
         if( parse_server_response() != 200 )
         {
            System.out.println("Invalid Server Response");
         }
         else 
         {     
            //change RTSP state and print out new state
            state = INIT;
            System.out.println("New RTSP state: INIT");

            //stop the timer
            timer.stop();

            //exit
            System.exit(0);
         }
      }
   }

   public void timer()
   {
      //Construct a DatagramPacket to receive data from the UDP socket
      rcvdp = new DatagramPacket(buf, buf.length);

      try
      {
         //receive the DP from the socket:
         RTPsocket.receive(rcvdp);
      }
      catch( InterruptedIOException e )
      {
         //System.out.println("Nothing to read");
      }
      catch (IOException e)
      {
         System.out.println("Exception caught: " + e);
      }

      //create an RTPpacket object from the DP
      RTPpacket RtpPacketObject = new RTPpacket(rcvdp.getData(), rcvdp.getLength());

      //print important header fields of the RTP packet received: 
      System.out.println("Got RTP packet with SeqNum # " + RtpPacketObject.getsequencenumber() + " TimeStamp " + RtpPacketObject.gettimestamp() + " ms, of type " + RtpPacketObject.getpayloadtype());

      boolean IsFecPacket;
      FecPacket FecPacketObj;

      IsFecPacket = RtpPacketObject.getpayloadtype() == RTPpacket.TYPE_FEC;

      if( IsFecPacket )
      {
         FecPacketObj = FecPacket.deSerilize(rcvdp.getData(), rcvdp.getLength());
      }

      if( !IsFecPacket )
      {
         // search a place where we can insert the packet
         int PacketIndex;
         boolean Inserted = false;
         boolean ThrowAway = false;

         for( PacketIndex = 0; PacketIndex < this.PacketList.size(); PacketIndex++ )
         {
            if( ( ((RTPpacket)this.PacketList.get(PacketIndex)).getsequencenumber() == RtpPacketObject.getsequencenumber() ) )
            {
               ThrowAway = true;
               break;
            }
         

            if( ((RTPpacket)this.PacketList.get(PacketIndex)).getsequencenumber() > RtpPacketObject.getsequencenumber() )
            {
               this.PacketList.add(PacketIndex, RtpPacketObject);
               Inserted = true;
               break;
            }
         }

         if( !Inserted && !ThrowAway )
         {
            this.PacketList.add(RtpPacketObject);
         }
      }
      else
      {
         // search a place where we can insert the packet
         int PacketIndex;
         boolean ThrowAway, Inserted;

         ThrowAway = false;
         Inserted = false;

         for( PacketIndex = 0; PacketIndex < this.FecPacketList.size(); PacketIndex++ )
         {
            FecPacket CurrentPacket;

            CurrentPacket = (FecPacket)this.FecPacketList.get(PacketIndex);

            if( CurrentPacket.SnBase == FecPacketObj.SnBase )
            {
               ThrowAway = true;
               break;
            }

            if( CurrentPacket.SnBase > FecPacketObj.SnBase )
            {
               this.FecPacketList.add(PacketIndex, FecPacketObj);
               Inserted = true;
               break;
            }
         }

         if( !Inserted && !ThrowAway )
         {
            this.FecPacketList.add(FecPacketObj);
         }
      }
      

      // TODO< enum >
      if( this.StreamState == 0 ) // Prebuffering
      {
         System.out.println("prebuffering");

         // TODO< calculate time >
         if( this.PacketList.size() > 15 )
         {
            this.StreamState = 1; // playing

            // set the sequence number to the First sequencenumber
            this.CurrentPlaySequenceNumber = ((FecPacket)this.PacketList.get(0)).getsequencenumber();

            this.FecReceivedFromServer = this.FecPacketList.length() > 0;

            if( this.FecReceivedFromServer )
            {
               this.CurrentFecSeqenceNumber = ((FecPacket)this.FecPacketList.get(0)).SnBase;
            }
         }
      }
      else if( this.StreamState == 1 ) // playing
      {
         // TODO< logic for FEC correction and stuff >

         

         // logic for fec correction
         if( this.FecReceivedFromServer )
         {
            // check if two successive packets are in the "PacketList", if so, transfer them and delete them and the FEC

            if(
               (this.PacketList.length >= 2) &&
               ( ((RTPPacket)this.PacketList.get(0)).getsequencenumber() == this.CurrentFecSeqenceNumber ) &&
               ( ((RTPPacket)this.PacketList.get(1)).getsequencenumber() == (this.CurrentFecSeqenceNumber + 1) )
            )
            {
               this.CorrectedPacketList.add((RTPPacket)this.PacketList.get(0));
               this.CorrectedPacketList.add((RTPPacket)this.PacketList.get(1));

               // search for a matching FEC packet and if found delete it
               if( this.FecPacketList.length >= 1 && ((FecPacket)(this.FecPacketList.get(0)).SnBase == this.CurrentFecSeqenceNumber) )
               {
                  this.FecPacketList.remove(0);
               }

               // remove the two packets

               this.PacketList.remove(0);
               this.PacketList.remove(0);

               this.CurrentFecSeqenceNumber += 2;
            }
            // check if we do have the Packet with the Sequencenumber n but not n+1 and if we have a fec packet with the sn base of n


            else if(
               (this.PacketList.length >= 1 ) &&
               ( ((RTPPacket)this.PacketList.get(0)).getsequencenumber() == this.CurrentFecSeqenceNumber ) &&
               ( ((FecPacket)this.FecPacketList.get(0)).SnBase == this.CurrentFecSeqenceNumber )
            )
            {
               // Reconstruct the Lost RTPPacket
               
            }

            // check if we do have the Packet with the Sequencenumer n+1 but not n and if we have a fec packet with the base n

            else if( TODO )

            // TODO

            else

         }
         else
         {
            // TODO
         }

         if( this.PacketList.length >= 2 )
         {
            if( this.FecPacketList.length >= 1 )
            {
               if(  )
            }
         }



         ////////////////////////////////

         RTPpacket CurrentNormalPacket;

         CurrentNormalPacket = (RTPpacket)this.PacketList.get(0);

         if( CurrentNormalPacket.getsequencenumber() == this.CurrentSequenceNumber )
         {
            this.PacketList.remove(0);

            // check if we need to delete some FEC packets
            for(;;)
            {
               FecPacket CurrentFecPacket;

               if( this.FecPacketList.length() == 0 )
               {
                  break;
               }

               CurrentFecPacket = (FecPacket)this.FecPacketList.get(0);

               if( CurrentFecPacket.SnBase < this.CurrentSequenceNumber-1 )
               {
                  this.FecPacketList.remove(0);
               }
            }

            

            this.ReceivedPackets++;

            // print header bitstream
            CurrentNormalPacket.printheader();

            // get the payload bitstream from the RTPpacket object
            int payload_length = CurrentNormalPacket.getpayload_length();
            System.out.println(payload_length);

            this.Datarate += payload_length;

            byte [] payload = new byte[payload_length];
            CurrentNormalPacket.getpayload(payload);

            // get an Image object from the payload bitstream
            Toolkit toolkit = Toolkit.getDefaultToolkit();
            Image image = toolkit.createImage(payload, 0, payload_length);
      
            // display the image as an ImageIcon object
            icon = new ImageIcon(image);
            iconLabel.setIcon(icon);

            
         }
         else
         {
            // try to calculate the lost packet with the matching FEC packet


         }
         

         this.CurrentPlaySequenceNumber++;

         this.CurrentPlayingTime += 20;
      }

      this.TimerMiliseconds += 20;

      if( this.TimerMiliseconds >= 1000 )
      {
         // display statistics and actualize counters

         // TODO< build in FEC popackets in the statistics? >

         float PacketLostRatio = ((float)(this.MaxSequenceNumber-this.ReceivedPackets))/(float)this.ReceivedPackets * 100.0f;

         System.out.println("Statistics:");
         System.out.println("Transmitted packets: " + this.ReceivedPackets);
         System.out.println("Lost packets       : " + (this.MaxSequenceNumber-this.ReceivedPackets));
         System.out.println("Packetlost-ratio   : " + PacketLostRatio + "%");
         System.out.println("Datarate           : " + this.Datarate);

         this.Datarate = 0;

         this.TimerMiliseconds = 0;
      }
   }

   //------------------------------------
   //Handler for timer
   //------------------------------------
  
   class TimerListener implements ActionListener
   {
      private Client ClientObject;

      public TimerListener(Client ClientObject)
      {
         this.ClientObject = ClientObject;
      }

      public void actionPerformed(ActionEvent Event)
      {
         this.ClientObject.timer();
      }
   }

   //------------------------------------
   //Parse Server Response
   //------------------------------------
   private int parse_server_response() 
   {
     int reply_code = 0;
 
      try
      {
         //parse status line and extract the reply_code:
         String StatusLine = RTSPBufferedReader.readLine();
         //System.out.println("RTSP Client - Received from Server:");
         System.out.println(StatusLine);
    
         StringTokenizer tokens = new StringTokenizer(StatusLine);
         tokens.nextToken(); //skip over the RTSP version
         reply_code = Integer.parseInt(tokens.nextToken());
      
         //if reply code is OK get and print the 2 other lines
         if( reply_code == 200 )
         {
            String SeqNumLine = RTSPBufferedReader.readLine();
            System.out.println(SeqNumLine);
     
            String SessionLine = RTSPBufferedReader.readLine();
            System.out.println(SessionLine);

            //if state == INIT gets the Session Id from the SessionLine
            tokens = new StringTokenizer(SessionLine);
            tokens.nextToken(); //skip over the Session:
            RTSPid = Integer.parseInt(tokens.nextToken());
         }
      }
      catch(Exception ex)
      {
         System.out.println("Exception caught: "+ex);
         System.exit(0);
      }
      
      return reply_code;
   }

   //------------------------------------
   //Send RTSP Request
   //------------------------------------

   private void send_RTSP_request(String request_type)
   {
      try
      {
         // Use the RTSPBufferedWriter to write to the RTSP socket
      
         //write the request line:
         RTSPBufferedWriter.write(request_type + " " + VideoFileName + " RTSP/1.0" + CRLF + "CSeq: " + RTSPSeqNb + CRLF);

         //check if request_type is equal to "SETUP" and in this case write the Transport: line advertising to the server the port used to receive the RTP packets RTP_RCV_PORT
         if( request_type == "SETUP" )
         {
            RTSPBufferedWriter.write("Transport: RTP/UDP; client_port= 25000" + CRLF);
         }
         else
         {
            // otherwise, write the Session line from the RTSPid field
            RTSPBufferedWriter.write("Session: " + RTSPid + CRLF);
         }
      
         RTSPBufferedWriter.flush();
      }
      catch(Exception e)
      {
         System.out.println("Exception caught: " + e);
         System.exit(0);
      }
   }
}
