with Giflib_Tooling.Session_State;
with Giflib_Tooling.Session_Types;
with Giflib_Tooling.Source_Tokens;

private package Giflib_Tooling.Session_Package_Aliases is
   package Semantics renames Giflib_Tooling.Session_Types;
   package Source renames Giflib_Tooling.Source_Tokens;
   package State renames Giflib_Tooling.Session_State;

   type Alias_Outcome is
     (Not_A_Renaming, Applied_Renaming, Invalid_Renaming);

   procedure Add
     (Tokens : Source.Token_Vectors.Vector;
      Index : Positive;
      Object : in out State.State;
      Context : in out Semantics.Type_Classification_Vectors.Vector;
      Budget : in out State.Budgets.Budget;
      Outcome : out Alias_Outcome);
end Giflib_Tooling.Session_Package_Aliases;
