import NameListObject : NameListObject;

class NameListConst : NameListObject
{
   this(int Value, uint Index)
   {
      this.Type = NameListObject.EnumType.CONST;

      this.Value = Value;
      this.Index = Index;
   }

   public int Value;
   public uint Index;
}
