with Ada.Strings.Unbounded;

with Giflib_Tooling.Configuration_Entries;
with Giflib_Tooling.Configuration_Normalization;
with Giflib_Tooling.Configuration_Values;

package body Giflib_Tooling.Configuration_Source is
   use Ada.Strings.Unbounded;
   package Entries renames Giflib_Tooling.Configuration_Entries;
   package Normalization renames
     Giflib_Tooling.Configuration_Normalization;
   package Values renames Giflib_Tooling.Configuration_Values;

   function Contains_Assignment
     (Text : String;
      Match : not null access function
        (Section : String;
         Is_Array : Boolean;
         Key : String;
         Value : String) return Boolean) return Query_Result
   is
      Current_Section : Unbounded_String;
      Current_Is_Array : Boolean := False;
      Section_Valid : Boolean := True;
      Found : Boolean := False;
      Malformed : Boolean := False;

      procedure Inspect (Item : Entries.Parsed_Entry; Stop : in out Boolean) is
      begin
         case Item.Kind is
            when Entries.Header_Entry =>
               Current_Section := Item.Section_Name;
               Current_Is_Array := Item.Is_Array_Section;
               Section_Valid := True;
            when Entries.Assignment_Entry =>
               Found := Found
                 or else
                   (Section_Valid
                    and then Match
                      (To_String (Current_Section), Current_Is_Array,
                       To_String (Item.Key), To_String (Item.Value)));
               Stop := False;
            when Entries.Malformed_Header_Entry =>
               Current_Section := Null_Unbounded_String;
               Current_Is_Array := False;
               Section_Valid := False;
               Malformed := True;
            when Entries.Malformed_Assignment_Entry =>
               Malformed := True;
            when Entries.Other_Entry =>
               null;
         end case;
      end Inspect;
   begin
      Entries.Scan (Text, Inspect'Access);
      return
        (if Malformed then Malformed_Input
         elsif Found then Assignment_Found
         else Assignment_Absent);
   end Contains_Assignment;

   function Has_Config_Assignment_Rebased
     (Text : String;
      Key : String;
      Value : String;
      Section : String := "";
      Array_Section : Boolean := False) return Query_Result
   is
      function Matches
        (Actual_Section : String;
         Is_Array : Boolean;
         Actual_Key : String;
         Actual_Value : String) return Boolean is
        (Actual_Section = Section
         and then Is_Array = Array_Section
         and then Actual_Key = Key
         and then Normalization.Normalize (Actual_Value) =
           Normalization.Normalize (Value));
   begin
      return Contains_Assignment (Text, Matches'Access);
   end Has_Config_Assignment_Rebased;

   function Has_Workspace_Pin_Rebased
     (Text : String; Crate : String; Relative_Path : String) return Query_Result
   is
      function Matches
        (Section : String;
         Is_Array : Boolean;
         Key : String;
         Value : String) return Boolean is
        (Section = "pins"
         and then Is_Array
         and then Key = Crate
         and then Values.Inline_String_Value_Matches
           (Value, "path", Relative_Path));
   begin
      return Contains_Assignment (Text, Matches'Access);
   end Has_Workspace_Pin_Rebased;

   function Find_Config_Assignment
     (Text : String;
      Key : String;
      Value : String;
      Section : String := "";
      Array_Section : Boolean := False) return Query_Result is
   begin
      if Text'Last <= Integer'Last - 3
        and then Value'Last <= Integer'Last - 3
      then
         return Has_Config_Assignment_Rebased
           (Text, Key, Value, Section, Array_Section);
      end if;
      declare
         Rebased_Text : constant String (1 .. Text'Length) := Text;
         Rebased_Value : constant String (1 .. Value'Length) := Value;
      begin
         return Has_Config_Assignment_Rebased
           (Rebased_Text, Key, Rebased_Value, Section, Array_Section);
      end;
   end Find_Config_Assignment;

   function Find_Workspace_Pin
     (Text : String; Crate : String; Relative_Path : String)
      return Query_Result is
   begin
      if Text'Last <= Integer'Last - 3 then
         return Has_Workspace_Pin_Rebased (Text, Crate, Relative_Path);
      end if;
      declare
         Rebased : constant String (1 .. Text'Length) := Text;
      begin
         return Has_Workspace_Pin_Rebased (Rebased, Crate, Relative_Path);
      end;
   end Find_Workspace_Pin;
end Giflib_Tooling.Configuration_Source;
