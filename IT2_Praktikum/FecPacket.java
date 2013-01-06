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

      ReturnPacket.SnBase = (Data[RtpPacketLength+2] << 8) | Data[RtpPacketLength+3];

      ReturnPacket.TsRecovery = (Data[RtpPacketLength+4] << 24) | (Data[RtpPacketLength+5] << 16) | (Data[RtpPacketLength+6] << 8) | Data[RtpPacketLength+7];

      ReturnPacket.LengthRecovery = (Data[RtpPacketLength+8] << 8) | Data[RtpPacketLength+9];

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

      // TODO< other fields? >

      Return.TimeStamp = Fec.TsRecovery ^ Rtp.TimeStamp;
      Return.CC = Fec.CCRecovery ^ Rtp.CC;
      RecoveredLength = Fec.LengthRecovery ^ Rtp.getpayload_length();
      Return.PayloadType = Fec.PTRecovery ^ Rtp.PayloadType;

      // note< sequence number recovery works only for 2 packet FEC >
      if( Fec.SnBase == Rtp.SequenceNumber )
      {
         Return.SequenceNumber = Rtp.SequenceNumber+1;
      }
      else
      {
         Return.SequenceNumber = Rtp.SequenceNumber-1;
      }
      
      System.out.print("reconstruct length ");
      System.out.println(RecoveredLength);

      
      MinLength = Fec.Payload.length;

      if( Rtp.payload.length < MinLength )
      {
         MinLength = Rtp.payload.length;
      }

      System.out.println(Fec.Payload.length);
      System.out.println(Rtp.payload.length);
      System.out.println(RecoveredLength);



      // allocate payload length
      Return.payload = new byte[RecoveredLength];


      if( Rtp.payload.length > RecoveredLength )
      {
         for( i = 0; i < RecoveredLength; i++ )
         {
            Return.payload[i] = Fec.Payload[i];
         }

         for( i = 0; i < RecoveredLength; i++ )
         {
            Return.payload[i] ^= Rtp.payload[i];
         }
      }
      else
      {
         for( i = 0; i < RecoveredLength; i++ )
         {
            Return.payload[i] = Rtp.payload[i];
         }

         for( i = 0; i < RecoveredLength; i++ )
         {
            Return.payload[i] ^= Fec.Payload[i];
         }
      }

      /*
      // xor payload
      for( i = 0; i < Length; i++ )
      {
         Return.payload[i] = (byte)(Fec.Payload[i] ^ Rtp.payload[i]);
      }
      */

      return Return;
   }
}
