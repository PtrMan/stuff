public class FecPacket
{
   public boolean ExtensionFlag;
   public boolean LongMaskFlag;
   public boolean PRecoveryFlag;
   public boolean XRecoveryFlag;
   public boolean MRecoveryFlag;

   public int CCRecovery;
   public int PTRecovery;
   
   public int SnBase;
   public int TsRecovery;
   public int LengthRecovery;

   public byte[] Payload;

   static int min(int A, int B)
   {
      if( A < B )
      {
         return A;
      }
      return B;
   }

   static FecPacket deSerilize(byte[] Data, int Length)
   {
      boolean LongMaskFlag;
      int RtpPacketLength;
      FecPacket ReturnPacket = new FecPacket();
      int HeaderLength; // sum of the header lengths
      int i;

      // TODO< read the length of the RTP packet >

      RtpPacketLength = 12;

      HeaderLength = 12 + 10;

      if( RtpPacketLength + 10 >= Length )
      {
         // wrong length
         return null;
      }

      // check if the extension flag is set
      ReturnPacket.ExtensionFlag = (Data[RtpPacketLength+0] & (1 << 7)) != 0;
      
      LongMaskFlag = (Data[RtpPacketLength+0] & (1 << 6)) != 0;

      ReturnPacket.LongMaskFlag = LongMaskFlag;
      if( LongMaskFlag )
      {
         HeaderLength += 8;
      }
      else
      {
         HeaderLength += 4;
      }

      if( Length < HeaderLength )
      {
         // wrong length
         return null;
      }

      ReturnPacket.PRecoveryFlag = (Data[RtpPacketLength+0] & (1 << 5)) != 0;

      ReturnPacket.XRecoveryFlag = (Data[RtpPacketLength+0] & (1 << 4)) != 0;

      ReturnPacket.CCRecovery = Data[RtpPacketLength+0] & 0xf;

      ReturnPacket.MRecoveryFlag = (Data[RtpPacketLength+1] & (1 << 7)) != 0;

      ReturnPacket.PTRecovery = Data[RtpPacketLength+1] & 0x7f;

      // we need & 0xff to convert from unsigned byte to int
      ReturnPacket.SnBase = ((Data[RtpPacketLength+2]&0xff) << 8) | (Data[RtpPacketLength+3]&0xff);

      //System.out.println("FecPacket.deSerilize()");

      //System.out.print("  SnBase ");
      //System.out.println(ReturnPacket.SnBase);


      // we need & 0xff to convert from unsigned byte to int
      ReturnPacket.TsRecovery = ((Data[RtpPacketLength+4]&0xff) << 24) | ((Data[RtpPacketLength+5]&0xff) << 16) | ((Data[RtpPacketLength+6]&0xff) << 8) | (Data[RtpPacketLength+7]&0xff);

      
      //System.out.print("  Data[20] ");
      //System.out.println(Data[RtpPacketLength+8]);

      //System.out.print("  Data[21] ");
      //System.out.println(Data[RtpPacketLength+9]);

      // we need & 0xff to convert from unsigned byte to int
      ReturnPacket.LengthRecovery = ((Data[RtpPacketLength+8] & 0xff)<< 8) | (Data[RtpPacketLength+9] & 0xff);

      //System.out.print("  LengthRecovery ");
      //System.out.println(ReturnPacket.LengthRecovery);

      // Extract Payload
      ReturnPacket.Payload = new byte[Length-HeaderLength];

      // copy Payload
      for( i = HeaderLength; i < Length; i++ )
      {
         ReturnPacket.Payload[i-HeaderLength] = Data[i];
      }

      return ReturnPacket;
   }

   static RTPpacket reconstruct(FecPacket Fec, RTPpacket Rtp)
   {
      RTPpacket Return = new RTPpacket();
      int RecoveredLength, i, MinLength;

      int WhichMin; // 0 : Rtp   1, recovered

      //System.out.println("FecPacket.reconstruct()");

      // TODO< other fields? >

      Return.TimeStamp = Fec.TsRecovery ^ Rtp.TimeStamp;
      Return.CC = Fec.CCRecovery ^ Rtp.CC;
      RecoveredLength = Fec.LengthRecovery ^ Rtp.getpayload_length();
      Return.PayloadType = Fec.PTRecovery ^ Rtp.PayloadType;

      //System.out.print("  SnBase ");
      //System.out.println(Fec.SnBase);

      // note< sequence number recovery works only for 2 packet FEC >
      if( Fec.SnBase == Rtp.SequenceNumber )
      {
         Return.SequenceNumber = Rtp.SequenceNumber+1;
      }
      else
      {
         Return.SequenceNumber = Rtp.SequenceNumber-1;
      }

      

      //System.out.println(Rtp.getpayload_length());

      //System.out.print("Fec.LengthRecovery");
      //System.out.println(Fec.LengthRecovery);

      //System.out.print("reconstruct length ");
      //System.out.println(RecoveredLength);

      // TODO< return null >

      assert RecoveredLength >= 0 : "RecoveredLength is less equal to zero";
      

      //System.out.print("Rtp length ");
      //System.out.println(Rtp.payload.length);

      //System.out.print("Fec length ");
      //System.out.println(Fec.Payload.length);

      // allocate payload length
      Return.payload = new byte[RecoveredLength];
      Return.payload_size = RecoveredLength;

      if( RecoveredLength <= Fec.Payload.length )
      {
         for( i = 0; i < RecoveredLength; i++ )
         {
            Return.payload[i] = Fec.Payload[i];
         }

         for( i = 0; i < min(RecoveredLength, Rtp.payload.length); i++ )
         {
            Return.payload[i] ^= Rtp.payload[i];
         }
      }
      else
      {
         for( i = 0; i < min(RecoveredLength, Rtp.payload.length); i++ )
         {
            Return.payload[i] = Rtp.payload[i];
         }
         
         for( i = 0; i < min(RecoveredLength, Fec.Payload.length); i++ )
         {
            Return.payload[i] ^= Fec.Payload[i];
         }
      }
      
      return Return;

   }
}
