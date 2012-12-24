import NameListObject : NameListObject;

class NameListVariable : NameListObject
{
   this(uint Displacement)
   {
      this.Type = NameListObject.EnumType.VARIABLE;

      this.Displacement = Displacement;
   }

   public uint Displacement;
}
