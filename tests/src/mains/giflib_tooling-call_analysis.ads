with Ada.Strings.Unbounded;

with Giflib_Tooling.Source_Tokens;

private package Giflib_Tooling.Call_Analysis is
   package Source renames Giflib_Tooling.Source_Tokens;

   type Callee_Status is (No_Callee, Callee_Found, Unrecognized_Callee);
   type Callee_Result (Status : Callee_Status := No_Callee) is record
      case Status is
         when Callee_Found =>
            Name : Ada.Strings.Unbounded.Unbounded_String;
         when No_Callee | Unrecognized_Callee =>
            null;
      end case;
   end record;

   function Image (Result : Callee_Result) return String
     with Pre => Result.Status = Callee_Found;

   function Callee_Before
     (Statement : Source.Token_Vectors.Vector;
      Open_Paren : Positive) return Callee_Result;
   function Enclosing_Callee
     (Statement : Source.Token_Vectors.Vector;
      Actual : Positive) return Callee_Result;
end Giflib_Tooling.Call_Analysis;
