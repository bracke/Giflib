package body Giflib.Internal.Owned_Vectors is
   function Next_Capacity
     (Current : Natural) return Positive
   is
   begin
      if Current = 0 then
         return Initial_Capacity;
      elsif Current > Natural'Last / 2 then
         return Positive (Current + 1);
      end if;
      return Positive (Current * 2);
   end Next_Capacity;

   function Ensure_Append
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is
   begin
      if Object.Count < Storage.Length (Object.Data) then
         return
           (Status => Ownership.Allocation_Ready,
            Attempted => Ownership.Used (Budget));
      elsif Object.Count = Natural'Last then
         return
           (Status => Ownership.Allocation_Size_Error,
            Attempted => Byte_Count'Last);
      end if;
      return Storage.Grow
        (Object.Data,
         Budget,
         Fault,
         First => 1,
         Last => Next_Capacity (Object.Count),
         Preserve => Object.Count,
         Maximum => Maximum);
   end Ensure_Append;

   procedure Append
     (Object : in out Handle;
      Value : Element_Type)
   is
   begin
      Object.Count := Object.Count + 1;
      Storage.Set_Element (Object.Data, Object.Count, Value);
   end Append;

   function Release
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean
   is
      Released : constant Boolean := Storage.Release (Object.Data, Budget);
   begin
      Object.Count := 0;
      return Released;
   end Release;

   function Is_Allocated (Object : Handle) return Boolean is
     (Storage.Is_Allocated (Object.Data));

   function Length (Object : Handle) return Natural is (Object.Count);

   function Capacity (Object : Handle) return Natural is
     (Storage.Length (Object.Data));

   function Element
     (Object : Handle;
      Index : Positive) return Element_Type
   is (Storage.Element (Object.Data, Index));
end Giflib.Internal.Owned_Vectors;
