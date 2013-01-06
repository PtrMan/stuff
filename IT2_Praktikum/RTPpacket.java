// TODO< code for decoding the FEC packet and for correction >
// TODO< move code for FEC into a own class >

public class RTPpacket
{
   // size of the RTP header
   static int HEADER_SIZE = 12;


   public static int TYPE_FEC = 127;



   // Fields that compose the RTP header
   public int Version;
   public int Padding;
   public int Extension;
   public int CC;
   public int Marker;
   public int PayloadType;
   public int SequenceNumber;
   public int TimeStamp;
   public int Ssrc;

   // Bitstream of the RTP header
   public byte[] Header;

   // size of the RTP payload
   public int payload_size;
   // Bitstream of the RTP payload
   public byte[] payload;

   // gets the complete data of the RTPpacket
   // NOTE< very hackinsh and unperformant >
   public byte[] getComplete()
   {
      byte[] Return;
      int i;

      this.rebuildHeader(this.PayloadType, this.SequenceNumber, this.TimeStamp);

      Return = new byte[this.Header.length + this.payload.length];

      i = 0;

      for( i = 0; i < this.Header.length; i++ )
      {
         Return[i] = this.Header[i];
      }

      for( i = 0; i < this.payload.length; i++ )
      {
         Return[i+this.Header.length] = this.payload[i];
      }

      return Return;
   }

   // constructor which is not initialisazing anything
   public RTPpacket()
   {
   }

   public void rebuildHeader(int PType, int SequenceNumber, int Time)
   {
      // fill by default header fields
      Version = 2;
      Padding = 0;
      Extension = 0;
      CC = 0;
      Marker = 0;
      Ssrc = 0;

      // fill changing header fields
      this.SequenceNumber = SequenceNumber;
      TimeStamp = Time;
      PayloadType = PType;
    
      // build the header bistream
      Header = new byte[HEADER_SIZE];

      //fill the header array with RTP header fields
      Header[0] = (byte)((this.CC & 0xf) | 0x80);
      Header[1] = (byte)(PType & 0x7f);
      Header[2] = (byte)(SequenceNumber / 0xFF);
      Header[3] = (byte)(SequenceNumber & 0xFF);
      Header[4] = (byte)((TimeStamp >> 24) & 0xFF);
      Header[5] = (byte)((TimeStamp >> 16) & 0xFF);
      Header[6] = (byte)((TimeStamp >> 8) & 0xFF);
      Header[7] = (byte)(TimeStamp & 0xFF);
      Header[8] = (byte)0;
      Header[9] = (byte)0;
      Header[10] = (byte)0;
      Header[11] = (byte)0;
   }

   // Constructor of an RTPpacket object from header fields and payload bitstream
   public RTPpacket(int PType, int SequenceNumber, int Time, byte[] data, int data_length)
   {
      this.rebuildHeader(PType, SequenceNumber, Time);

      // fill the payload bitstream
      this.payload_size = data_length;
      payload = new byte[data_length];

      // fill payload array of byte from data (given in parameter of the constructor)
      for( int i=0; i < data_length; i++ )
      {
         payload[i] = data[i];
      }
   }

   // SequenceNumber : the Sequence number of the FEC Packet (see RFC)
   //                  ... The sequence number has the standard definition ...
   static byte[] buildFecPacket(RTPpacket A, RTPpacket B, int SequenceNumber, int TimeStamp)
   {
      byte[] Return;
      int LowestSequenceNumber;
      int TimeStampRecovery;
      int LengthA, LengthB;
      int XorLength;
      int ProtectionLength;
      int Mask;

      System.out.println("BuildFecPacket");

      if( A.getpayload_length() > B.getpayload_length() )
      {
         ProtectionLength = A.getpayload_length();
      }
      else
      {
         ProtectionLength = B.getpayload_length();
      }

      Return = new byte[26 + ProtectionLength];

      // RTP header
      Return[0] = (byte)((A.getCc() & 0xf) | 0x80);
      Return[1] = (byte)(TYPE_FEC & 0x7f); // it is a FEC-packet
      Return[2] = (byte)(SequenceNumber / 0xff);
      Return[3] = (byte)(SequenceNumber & 0xff);
      Return[4] = (byte)((TimeStamp >> 24) & 0xFF);
      Return[5] = (byte)((TimeStamp >> 16) & 0xFF);
      Return[6] = (byte)((TimeStamp >> 8) & 0xFF);
      Return[7] = (byte)(TimeStamp & 0xFF);
      Return[8] = (byte)0;
      Return[9] = (byte)0;
      Return[10] = (byte)0;
      Return[11] = (byte)0;

      // FEC header
      Return[12] = (byte)((A.at(12) ^ B.at(12)) & 0x3f);
      Return[13] = (byte)(A.at(13) ^ B.at(13));

      System.out.print("  SequenceNumber A ");
      System.out.println(A.getsequencenumber());
      System.out.print("  SequenceNumber B ");
      System.out.println(B.getsequencenumber());

      if( A.getsequencenumber() < B.getsequencenumber() )
      {
         LowestSequenceNumber = A.getsequencenumber();
      }
      else
      {
         LowestSequenceNumber = B.getsequencenumber();
      }
      
      Return[14] = (byte)(LowestSequenceNumber >> 8);
      Return[15] = (byte)(LowestSequenceNumber & 0xff);

      TimeStampRecovery = A.gettimestamp() ^ B.gettimestamp();

      Return[16] = (byte)((TimeStampRecovery >> 24) & 0xFF);
      Return[17] = (byte)((TimeStampRecovery >> 16) & 0xFF);
      Return[18] = (byte)((TimeStampRecovery >> 8) & 0xFF);
      Return[19] = (byte)(TimeStampRecovery & 0xFF);

      // Length of Media payload + 0 /* length of CSRC list */ + 0 /* length of extensions */ + 0 /* length of padding */
      LengthA = A.getpayload_length();
      LengthB = B.getpayload_length();

      
      System.out.print("  LengthA ");
      System.out.println(LengthA);
      System.out.print("  LengthB ");
      System.out.println(LengthB);

      XorLength = LengthA ^ LengthB;

      System.out.print("  XorLength ");
      System.out.println(XorLength);

      // length recovery
      Return[20] = (byte)((XorLength >> 8) & 0xff);
      Return[21] = (byte)(XorLength & 0xff);

      System.out.print("  Return[20]");
      System.out.println(Return[20]);

      System.out.print("  Return[21]");
      System.out.println(Return[21]);

      // FEC level 0 header


      Return[22] = (byte)((ProtectionLength >> 8) & 0xff);
      Return[23] = (byte)(ProtectionLength & 0xff);

      Mask = 1;

      Return[24] = (byte)((Mask >> 8) & 0xff);
      Return[25] = (byte)(Mask & 0xff);

      // write data of the bigger packet and xor the smaller over it
      if( A.getpayload_length() > B.getpayload_length() )
      {
         for(int i = 0; i < A.getpayload_length(); i++ )
         {
            Return[26+i] = A.at(HEADER_SIZE+i);
         }

         for(int i = 0; i < B.getpayload_length(); i++ )
         {
            Return[26+i] = (byte)(Return[26+i] ^ B.at(HEADER_SIZE+i));
         }
      }
      else
      {
         for(int i = 0; i < B.getpayload_length(); i++ )
         {
            Return[26+i] = B.at(HEADER_SIZE+i);
         }

         for(int i = 0; i < A.getpayload_length(); i++ )
         {
            Return[26+i] = (byte)(Return[26+i] ^ A.at(HEADER_SIZE+i));
         }
      }

      return Return;
   }

   public int getCc()
   {
      return this.CC;
   }

   // crappy hack for shity code
   public byte at(int Index)
   {
      if( Index >= HEADER_SIZE )
      {
         return this.payload[Index - HEADER_SIZE];
      }
      else
      {
         return this.Header[Index];
      }
   }

   //--------------------------
   //Constructor of an RTPpacket object from the packet bistream 
   //--------------------------
   public RTPpacket(byte[] packet, int packet_size)
   {
      //fill default fields:
      Version = 2;
      Padding = 0;
      Extension = 0;
      CC = 0;
      Marker = 0;
      Ssrc = 0;
 
      //check if total packet size is lower than the header size
      if (packet_size < HEADER_SIZE) 
      {
         return;
      }

      //get the header bitsream:
      Header = new byte[HEADER_SIZE];
      for (int i=0; i < HEADER_SIZE; i++)
      {
         Header[i] = packet[i];
      }

      //get the payload bitstream:
      payload_size = packet_size - HEADER_SIZE;
      payload = new byte[payload_size];
      for (int i=HEADER_SIZE; i < packet_size; i++)
      {
         payload[i-HEADER_SIZE] = packet[i];
      }
         
      //interpret the changing fields of the header:
      PayloadType = Header[1] & 127;
      SequenceNumber = unsigned_int(Header[3]) + 256*unsigned_int(Header[2]);
      TimeStamp = unsigned_int(Header[7]) + 256*unsigned_int(Header[6]) + 65536*unsigned_int(Header[5]) + 16777216*unsigned_int(Header[4]);
   }

   // return the payload bistream of the RTPpacket and its size
   public int getpayload(byte[] data)
   {
      for( int i=0; i < this.payload_size; i++ )
      {
         data[i] = payload[i];
      }
      
      return payload_size;
   }

   // return the length of the payload
   public int getpayload_length()
   {
      return payload_size;
   }

   // return the total length of the RTP packet
   public int getlength()
   {
      return payload_size + HEADER_SIZE;
   }

   // returns the packet bitstream and its length
   public int getpacket(byte[] packet)
   {
      //construct the packet = header + payload
      for( int i=0; i < HEADER_SIZE; i++ )
      {
         packet[i] = Header[i];
      }
      
      for (int i=0; i < this.payload_size; i++)
      {
         packet[i+HEADER_SIZE] = payload[i];
      }

      //return total size of the packet
      return this.payload_size + HEADER_SIZE;
   }

   public int gettimestamp()
   {
      return TimeStamp;
   }

   public int getsequencenumber()
   {
      return SequenceNumber;
   }

   public int getpayloadtype()
   {
      return PayloadType;
   }


   //--------------------------
   //print headers without the SSRC
   //--------------------------
   public void printheader()
   {
      //TO DO: uncomment
      /*
       for (int i=0; i < (HEADER_SIZE-4); i++)
       {
   for (int j = 7; j>=0 ; j--)
     if (((1<<j) & header[i] ) != 0)
       System.out.print("1");
   else
     System.out.print("0");
   System.out.print(" ");
      }
   
    System.out.println();
    */
   }

   //return the unsigned value of 8-bit integer nb
   static int unsigned_int(int nb)
   {
      if (nb >= 0)
      {
         return nb;
      }
      else
      {
         return(256+nb);
      }
   }
}
