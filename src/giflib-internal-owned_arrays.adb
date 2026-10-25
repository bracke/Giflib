with Ada.Unchecked_Deallocation;

package body Giflib.Internal.Owned_Arrays is
   use type Ownership.Allocation_Status;

   procedure Free is new Ada.Unchecked_Deallocation
     (Element_Array, Element_Array_Access);

   function Element_Bytes return Byte_Count is
     (Ownership.Storage_Bytes (Element_Type'Object_Size));

   function Allocation_Bytes (Length : Natural) return Byte_Count is
     (if Element_Bytes = 0
      then 0
      elsif Byte_Count (Length) > Byte_Count'Last / Element_Bytes
      then Byte_Count'Last
      else Byte_Count (Length) * Element_Bytes);

   function Ensure
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      First : Index_Type;
      Last : Index_Type;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is
   begin
      return Grow
        (Object,
         Budget,
         Fault,
         First,
         Last,
         Preserve => 0,
         Maximum => Maximum);
   end Ensure;

   function Grow
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      First : Index_Type;
      Last : Index_Type;
      Preserve : Natural;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome
   is
      Span : constant Long_Long_Integer :=
        Long_Long_Integer (Last) - Long_Long_Integer (First);
      Outcome : Ownership.Allocation_Outcome;
      New_Pointer : Element_Array_Access;
      New_Charge : Byte_Count;
      Old_Charge : Byte_Count := 0;
   begin
      if Object.Borrowed then
         return
           (Status => Ownership.Allocation_Borrow_Error,
            Attempted => Ownership.Used (Budget));
      elsif not Ownership.Matches (Object.Owner, Budget) then
         return
           (Status => Ownership.Allocation_Owner_Error,
            Attempted => Ownership.Used (Budget));
      elsif Span >= Long_Long_Integer (Natural'Last) then
         return
           (Status => Ownership.Allocation_Size_Error,
            Attempted => Byte_Count'Last);
      end if;
      declare
         Required_Length : constant Positive := Natural (Span) + 1;
      begin
         if Preserve > Required_Length
           or else (Preserve > 0
                    and then (Object.Pointer = null
                              or else Preserve > Object.Pointer'Length))
         then
            return
              (Status => Ownership.Allocation_Size_Error,
               Attempted => Byte_Count'Last);
         elsif Object.Pointer /= null
           and then Object.Pointer'First = First
           and then Object.Pointer'Length >= Required_Length
         then
            return
              (Status => Ownership.Allocation_Ready,
               Attempted => Ownership.Used (Budget));
         end if;

         New_Charge := Allocation_Bytes (Required_Length);
         declare
            Ticket : Ownership.Reservation (Budget'Access);
            procedure Allocate is
            begin
               New_Pointer :=
                 new Element_Array'(First .. Last => Default_Element);
            end Allocate;
            procedure Perform is new Ownership.Reserve_And_Allocate (Allocate);
         begin
            Perform (Ticket, Fault, Maximum, New_Charge, Outcome);
         end;
         if Outcome.Status /= Ownership.Allocation_Ready then
            return Outcome;
         end if;
         if Preserve > 0 then
            for Offset in 0 .. Preserve - 1 loop
               New_Pointer
                 (Index_Type'Val (Index_Type'Pos (First) + Offset)) :=
                   Object.Pointer
                     (Index_Type'Val
                        (Index_Type'Pos (Object.Pointer'First) + Offset));
            end loop;
         end if;
         if Object.Pointer /= null then
            Old_Charge := Allocation_Bytes (Object.Pointer'Length);
            if not Ownership.Release (Budget, Old_Charge) then
               Ownership.Rollback (Budget, New_Charge);
               Free (New_Pointer);
               return
                 (Status => Ownership.Allocation_Owner_Error,
                  Attempted => Ownership.Used (Budget));
            end if;
            Free (Object.Pointer);
         else
            Ownership.Bind (Object.Owner, Budget);
         end if;
         Object.Pointer := New_Pointer;
         return
           (Status => Ownership.Allocation_Ready,
            Attempted => Ownership.Used (Budget));
      end;
   end Grow;

   function Release
     (Object : in out Handle;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean
   is
      Released : Boolean;
   begin
      if Object.Borrowed then
         return False;
      elsif not Ownership.Matches (Object.Owner, Budget) then
         return False;
      end if;
      if Object.Pointer /= null then
         Released := Ownership.Release_Owned
           (Object.Owner, Budget, Allocation_Bytes (Object.Pointer'Length));
         Free (Object.Pointer);
      else
         Released := Ownership.Release_Owned (Object.Owner, Budget, 0);
      end if;
      return Released;
   end Release;

   function Is_Allocated (Object : Handle) return Boolean is
     (Object.Pointer /= null);

   function Is_Borrowed (Object : Handle) return Boolean is
     (Object.Borrowed);

   function Matches
     (Object : Handle;
      Budget : aliased Ownership.Byte_Budget) return Boolean
   is (Ownership.Matches (Object.Owner, Budget));

   function Contains
     (Object : Handle;
      Index : Index_Type) return Boolean
   is
     (Object.Pointer /= null and then Index in Object.Pointer'Range);

   function Length (Object : Handle) return Natural is
     (if Object.Pointer = null then 0 else Object.Pointer'Length);

   procedure Query
     (Object : in out Handle;
      Process : not null access procedure (Value : Element_Array))
   is
      Acquired : Boolean := False;
   begin
      if Object.Borrowed then
         raise Program_Error with "owned array is already borrowed";
      end if;
      Object.Borrowed := True;
      Acquired := True;
      Process (Object.Pointer.all);
      Object.Borrowed := False;
   exception
      when others =>
         if Acquired then
            Object.Borrowed := False;
         end if;
         raise;
   end Query;

   procedure Update
     (Object : in out Handle;
      Process : not null access procedure (Value : in out Element_Array))
   is
      Acquired : Boolean := False;
   begin
      if Object.Borrowed then
         raise Program_Error with "owned array is already borrowed";
      end if;
      Object.Borrowed := True;
      Acquired := True;
      Process (Object.Pointer.all);
      Object.Borrowed := False;
   exception
      when others =>
         if Acquired then
            Object.Borrowed := False;
         end if;
         raise;
   end Update;

   procedure Query_Update
     (Source : in out Handle;
      Target : in out Handle;
      Process : not null access procedure
        (Source_Value : Element_Array;
         Target_Value : in out Element_Array))
   is
      Source_Acquired : Boolean := False;
      Target_Acquired : Boolean := False;
   begin
      if Source.Borrowed or else Target.Borrowed then
         raise Program_Error with "owned array is already borrowed";
      elsif Source.Pointer = Target.Pointer then
         raise Program_Error with "owned array cannot borrow itself twice";
      end if;
      Source.Borrowed := True;
      Source_Acquired := True;
      Target.Borrowed := True;
      Target_Acquired := True;
      Process (Source.Pointer.all, Target.Pointer.all);
      Target.Borrowed := False;
      Source.Borrowed := False;
   exception
      when others =>
         if Target_Acquired then
            Target.Borrowed := False;
         end if;
         if Source_Acquired then
            Source.Borrowed := False;
         end if;
         raise;
   end Query_Update;

   function Element
     (Object : Handle;
      Index : Index_Type) return Element_Type
   is (Object.Pointer (Index));

   procedure Set_Element
     (Object : in out Handle;
      Index : Index_Type;
      Value : Element_Type)
   is
   begin
      if Object.Borrowed then
         raise Program_Error with "owned array is already borrowed";
      end if;
      Object.Pointer (Index) := Value;
   end Set_Element;
end Giflib.Internal.Owned_Arrays;
