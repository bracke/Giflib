package body Giflib_Tooling.Suite_Flow_Ranges is
   procedure Initialize
     (Object : out Tracker;
      Ranges : Giflib_Tooling.Scope_Analysis.Subprogram_Range_Vectors.Vector)
   is
   begin
      Object := (others => <>);
      if not Ranges.Is_Empty then
         Object.Cursor := (Present => True, Value => Ranges.First_Index);
      end if;
   end Initialize;

   function Is_Nested
     (Object : in out Tracker;
      Ranges : Giflib_Tooling.Scope_Analysis.Subprogram_Range_Vectors.Vector;
      Index : Positive;
      Selection_First : Positive) return Boolean is
   begin
      while not Object.Active_Ends.Is_Empty
        and then Object.Active_Ends.Last_Element < Index
      loop
         Object.Active_Ends.Delete_Last;
      end loop;
      while Object.Cursor.Present
        and then Object.Cursor.Value <= Ranges.Last_Index
        and then Ranges (Object.Cursor.Value).First < Index
      loop
         if Object.Cursor.Value = Ranges.Last_Index then
            Object.Cursor := (Present => False);
         else
            Object.Cursor.Value := Object.Cursor.Value + 1;
         end if;
      end loop;
      while Object.Cursor.Present
        and then Object.Cursor.Value <= Ranges.Last_Index
        and then Ranges (Object.Cursor.Value).First = Index
      loop
         declare
            Item : Giflib_Tooling.Scope_Analysis.Subprogram_Range renames
              Ranges (Object.Cursor.Value);
         begin
            if Item.First > Selection_First
              and then Item.Complete
              and then Item.Last > Item.First
            then
               Object.Active_Ends.Append (Item.Last);
            end if;
         end;
         if Object.Cursor.Value = Ranges.Last_Index then
            Object.Cursor := (Present => False);
         else
            Object.Cursor.Value := Object.Cursor.Value + 1;
         end if;
      end loop;
      return not Object.Active_Ends.Is_Empty;
   end Is_Nested;
end Giflib_Tooling.Suite_Flow_Ranges;
