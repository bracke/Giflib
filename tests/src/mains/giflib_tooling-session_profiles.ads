with Ada.Strings.Unbounded;

with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Source_Tokens;

private package Giflib_Tooling.Session_Profiles is
   package Semantics renames Giflib_Tooling.Session_Types;
   package Source renames Giflib_Tooling.Source_Tokens;

   type Type_Name_Status is
     (Type_Name_Absent, Type_Name_Found, Anonymous_Subprogram_Access);
   type Type_Name_Result (Status : Type_Name_Status := Type_Name_Absent) is record
      case Status is
         when Type_Name_Found =>
            Name : Ada.Strings.Unbounded.Unbounded_String;
         when Type_Name_Absent | Anonymous_Subprogram_Access =>
            null;
      end case;
   end record;

   function Image (Result : Type_Name_Result) return String
     with Pre => Result.Status = Type_Name_Found;

   function Build
     (Tokens : Source.Token_Vectors.Vector;
      Function_Index : Positive;
      Return_Index : Positive;
      Profile_Last : Positive) return Semantics.Callable_Profile;
   function Type_Name
     (Tokens : Source.Token_Vectors.Vector;
      First : Positive;
      Last : Positive) return Type_Name_Result;
   function Simple_Name (Name : String) return String;
end Giflib_Tooling.Session_Profiles;
