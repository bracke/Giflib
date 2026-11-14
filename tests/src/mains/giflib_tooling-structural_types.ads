with Ada.Strings.Unbounded;

private package Giflib_Tooling.Structural_Types is
   type Token_Position (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Positive;
         when False =>
            null;
      end case;
   end record;
   No_Position : constant Token_Position := (Present => False);

   type Subprogram_Header is record
      Profile : Ada.Strings.Unbounded.Unbounded_String;
      Return_Marker : Token_Position := No_Position;
      Declaration_Last : Token_Position := No_Position;
      Introduces_Scope : Boolean := False;
      Is_Body : Boolean := False;
   end record;
end Giflib_Tooling.Structural_Types;
