with Ada.Strings.Unbounded;

package body Giflib_Tooling.Suite_Source_Selection is
   use Ada.Strings.Unbounded;
   use type Giflib_Tooling.Source_Tokens.Token_Kind;
   package Model renames Giflib_Tooling.Source_Model;
   package Scopes renames Giflib_Tooling.Scope_Analysis;
   package Syntax renames Giflib_Tooling.Source_Events;
   package Tokens renames Giflib_Tooling.Source_Tokens;

   function Profile_Matches
     (Items : Tokens.Token_Vectors.Vector;
      Start : Positive;
      Profile : Profile_Kind) return Boolean
   is
   begin
      if Start + 2 > Items.Last_Index then
         return False;
      elsif Profile = All_Tests_Profile then
         return Tokens.Image (Items (Start)) = "function"
           and then Tokens.Image (Items (Start + 2)) = "return";
      elsif Tokens.Image (Items (Start)) /= "procedure"
        or else Tokens.Image (Items (Start + 2)) /= "("
      then
         return False;
      end if;
      return Start + 8 <= Items.Last_Index
        and then Tokens.Kind_Of (Items (Start + 3)) = Tokens.Identifier
        and then Tokens.Image (Items (Start + 4)) = ":"
        and then Tokens.Image (Items (Start + 5)) = "in"
        and then Tokens.Image (Items (Start + 6)) = "out"
        and then Tokens.Image (Items (Start + 7)) = "test"
        and then Tokens.Image (Items (Start + 8)) = ")";
   end Profile_Matches;

   procedure Inspect_Body
     (Parsed : Model.Parsed_Source;
      Budget : in out Giflib_Tooling.Work_Budgets.Budget;
      Name : String;
      Profile : Profile_Kind;
      Process : not null access procedure
        (Selected : Selected_Body;
         Tokens : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
         Events : Giflib_Tooling.Source_Events.Structural_Event_Vectors.Vector;
         Ranges :
           Giflib_Tooling.Scope_Analysis.Subprogram_Range_Vectors.Vector))
   is
      type Match_Kind is (No_Match, Unique_Match, Ambiguous_Match);
      type Match_Result (Kind : Match_Kind := No_Match) is record
         case Kind is
            when Unique_Match =>
               First : Positive;
               Body_First : Positive;
               Last : Positive;
            when No_Match | Ambiguous_Match =>
               null;
         end case;
      end record;
      Ranges : constant Scopes.Subprogram_Range_Vectors.Vector :=
        Scopes.Subprogram_Ranges (Parsed, Budget);
      procedure Inspect_Syntax
        (Items : Tokens.Token_Vectors.Vector;
         Events : Syntax.Structural_Event_Vectors.Vector)
      is
         Match : Match_Result;
      begin
         for Item of Ranges loop
            if To_String (Item.Name) = Name
              and then Item.Directly_In_Package
              and then Item.Depth = 1
              and then Item.Complete
              and then Item.Last > Item.Body_First
              and then Profile_Matches (Items, Item.First, Profile)
            then
               if Match.Kind = No_Match then
                  Match :=
                    (Kind => Unique_Match,
                     First => Item.First,
                     Body_First => Item.Body_First,
                     Last => Item.Last);
               else
                  Match := (Kind => Ambiguous_Match);
               end if;
            end if;
         end loop;
         if Match.Kind /= Unique_Match then
            Process ((Found => False), Items, Events, Ranges);
         else
            Process
              ((Found => True,
                First => Match.First,
                Body_First => Match.Body_First,
                Last => Match.Last),
               Items, Events, Ranges);
         end if;
      end Inspect_Syntax;
   begin
      Model.Inspect_Syntax (Parsed, Inspect_Syntax'Access);
   end Inspect_Body;
end Giflib_Tooling.Suite_Source_Selection;
