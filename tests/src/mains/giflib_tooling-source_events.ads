with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Giflib_Tooling.Structural_Types;

private package Giflib_Tooling.Source_Events is
   use Ada.Strings.Unbounded;
   type Structural_Event_Kind is
     (No_Structural_Event, Subprogram_Start, Package_Start, Program_Start,
      Block_Start, Record_Start, Scope_End, Record_End, Loop_End, Return_End,
      Control_End);
   type Structural_Event
     (Kind : Structural_Event_Kind := No_Structural_Event) is record
      Token_Index : Positive := 1;
      case Kind is
         when Subprogram_Start =>
            Subprogram_Name : Unbounded_String;
            Header : Giflib_Tooling.Structural_Types.Subprogram_Header;
         when Package_Start =>
            Package_Name : Unbounded_String;
            Package_Introduces_Scope : Boolean := False;
            Package_Is_Body : Boolean := False;
         when Program_Start =>
            Program_Name : Unbounded_String;
         when Block_Start =>
            Block_Name : Unbounded_String;
         when Record_Start =>
            Record_Name : Unbounded_String;
         when Scope_End =>
            Ending_Name : Unbounded_String;
         when No_Structural_Event | Record_End | Loop_End | Return_End |
           Control_End =>
            null;
      end case;
   end record;
   subtype Subprogram_Event is Structural_Event (Subprogram_Start);
   package Structural_Event_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Structural_Event);
end Giflib_Tooling.Source_Events;
