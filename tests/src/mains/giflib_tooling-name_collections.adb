package body Giflib_Tooling.Name_Collections is
   function Contains
     (Names : Name_Vectors.Vector; Name : String) return Boolean is
   begin
      for Item of Names loop
         if Ada.Strings.Unbounded.To_String (Item) = Name then
            return True;
         end if;
      end loop;
      return False;
   end Contains;

   function Value (Name : Unbounded_String) return String is
     (Ada.Strings.Unbounded.To_String (Name));
end Giflib_Tooling.Name_Collections;
