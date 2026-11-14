with Ada.Directories;
with Ada.Finalization;

private package Giflib_Tooling.Repository_Searches is
   type Cleanup_Status is (Cleanup_Complete, Cleanup_Failed);
   Search_Failed : exception;
   type Search
     (Cleanup_State : not null access Cleanup_Status) is
       new Ada.Finalization.Limited_Controlled with private;

   procedure Start (Object : in out Search; Directory : String);
   function More_Entries (Object : Search) return Boolean;
   procedure Next_Entry
     (Object : in out Search;
      Item : out Ada.Directories.Directory_Entry_Type);
   procedure Finish (Object : in out Search);
   function First_Cleanup_Status (Object : Search) return Cleanup_Status;
   overriding procedure Finalize (Object : in out Search);
private
   type Search
     (Cleanup_State : not null access Cleanup_Status) is
       new Ada.Finalization.Limited_Controlled with record
      Value : Ada.Directories.Search_Type;
      Started : Boolean := False;
   end record;
end Giflib_Tooling.Repository_Searches;
