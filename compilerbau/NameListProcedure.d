import NameListObject : NameListObject;
import Hashtable : Hashtable;

class NameListProcedure : NameListObject
{
   this()
   {
      this.ProcedureIndex = 0;
      this.Parent = cast(NameListProcedure*)0;
      this.MemoryCounter = 0;
   }

   public uint ProcedureIndex;
   public NameListProcedure *Parent;

   public Hashtable!(string, NameListObject, 16) Entities;

   public uint MemoryCounter; // Memory-assignment counter for Variable
}
