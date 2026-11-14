package body Giflib_Tooling.Repository_Searches is
   procedure Start (Object : in out Search; Directory : String) is
   begin
      Finish (Object);
      begin
         Ada.Directories.Start_Search (Object.Value, Directory, "");
         Object.Started := True;
      exception
         when Ada.Directories.Name_Error | Ada.Directories.Use_Error |
              Ada.Directories.Status_Error =>
            raise Search_Failed with "cannot start repository search";
      end;
   end Start;

   function More_Entries (Object : Search) return Boolean is
   begin
      if not Object.Started then
         return False;
      end if;
      return Ada.Directories.More_Entries (Object.Value);
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error |
           Ada.Directories.Status_Error =>
         raise Search_Failed with "cannot inspect repository search";
   end More_Entries;

   procedure Next_Entry
     (Object : in out Search;
      Item : out Ada.Directories.Directory_Entry_Type) is
   begin
      begin
         Ada.Directories.Get_Next_Entry (Object.Value, Item);
      exception
         when Ada.Directories.Name_Error | Ada.Directories.Use_Error |
              Ada.Directories.Status_Error =>
            raise Search_Failed with "cannot read repository search entry";
      end;
   end Next_Entry;

   procedure Finish (Object : in out Search) is
   begin
      if Object.Started then
         Object.Started := False;
         begin
            Ada.Directories.End_Search (Object.Value);
         exception
            when Ada.Directories.Name_Error | Ada.Directories.Use_Error |
                 Ada.Directories.Status_Error =>
               Object.Cleanup_State.all := Cleanup_Failed;
         end;
      end if;
   end Finish;

   function First_Cleanup_Status (Object : Search) return Cleanup_Status is
     (Object.Cleanup_State.all);

   overriding procedure Finalize (Object : in out Search) is
   begin
      Finish (Object);
   end Finalize;
end Giflib_Tooling.Repository_Searches;
