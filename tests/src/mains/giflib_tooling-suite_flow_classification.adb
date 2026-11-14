package body Giflib_Tooling.Suite_Flow_Classification is
   package Model renames Giflib_Tooling.Source_Tokens;
   use type Model.Token_Kind;

   function Follows_Label
     (Tokens : Model.Token_Vectors.Vector; Index : Positive) return Boolean is
     (Index >= Tokens.First_Index + 5
      and then Model.Image (Tokens (Index - 1)) = ">"
      and then Model.Image (Tokens (Index - 2)) = ">"
      and then Model.Kind_Of (Tokens (Index - 3)) = Model.Identifier
      and then Model.Image (Tokens (Index - 4)) = "<"
      and then Model.Image (Tokens (Index - 5)) = "<");

   function At_Statement_Start
     (Tokens : Model.Token_Vectors.Vector; Index : Positive) return Boolean is
     (Index = Tokens.First_Index
      or else Follows_Label (Tokens, Index)
      or else Model.Image (Tokens (Index - 1)) in
        "begin" | ";" | "then" | "else" | "=>" | "loop");

   function Is_Label_Name
     (Tokens : Model.Token_Vectors.Vector; Index : Positive) return Boolean is
     (Index >= Tokens.First_Index + 2
      and then Index + 2 <= Tokens.Last_Index
      and then Model.Image (Tokens (Index - 2)) = "<"
      and then Model.Image (Tokens (Index - 1)) = "<"
      and then Model.Kind_Of (Tokens (Index)) = Model.Identifier
      and then Model.Image (Tokens (Index + 1)) = ">"
      and then Model.Image (Tokens (Index + 2)) = ">");

   function Classify
     (Tokens : Model.Token_Vectors.Vector; Index : Positive) return Flow_Event
   is
      Image : constant String := Model.Image (Tokens (Index));
   begin
      if Is_Label_Name (Tokens, Index) then
         return
           (Label_Reached,
            Ada.Strings.Unbounded.To_Unbounded_String (Image));
      elsif Image = "end" and then Index < Tokens.Last_Index then
         if Model.Image (Tokens (Index + 1)) = "if" then
            return (Kind => If_Closed, others => <>);
         elsif Model.Image (Tokens (Index + 1)) = "case" then
            return (Kind => Case_Closed, others => <>);
         elsif Model.Image (Tokens (Index + 1)) = "select" then
            return (Kind => Select_Closed, others => <>);
         elsif Model.Image (Tokens (Index + 1)) = "loop" then
            return (Kind => Loop_Closed, others => <>);
         end if;
      elsif At_Statement_Start (Tokens, Index) and then Image = "if" then
         return (Kind => If_Opened, others => <>);
      elsif At_Statement_Start (Tokens, Index) and then Image = "case" then
         return (Kind => Case_Opened, others => <>);
      elsif At_Statement_Start (Tokens, Index) and then Image = "select" then
         return (Kind => Select_Opened, others => <>);
      elsif Image = "loop"
        and then (Index = Tokens.First_Index
                  or else Model.Image (Tokens (Index - 1)) /= "end")
      then
         return (Kind => Loop_Opened, others => <>);
      elsif Image = "exception" then
         return (Kind => Exception_Started, others => <>);
      elsif Image = "when"
        and then Index < Tokens.Last_Index
        and then Model.Image (Tokens (Index + 1)) = "others"
      then
         return (Kind => Catch_All_Started, others => <>);
      elsif At_Statement_Start (Tokens, Index) and then Image = "return" then
         return (Kind => Return_Statement, others => <>);
      elsif At_Statement_Start (Tokens, Index) and then Image = "raise" then
         return (Kind => Raise_Statement, others => <>);
      elsif At_Statement_Start (Tokens, Index)
        and then Image = "goto"
        and then Index < Tokens.Last_Index
        and then Model.Kind_Of (Tokens (Index + 1)) = Model.Identifier
      then
         return
           (Goto_Statement,
            Ada.Strings.Unbounded.To_Unbounded_String
              (Model.Image (Tokens (Index + 1))));
      end if;
      return (others => <>);
   end Classify;
end Giflib_Tooling.Suite_Flow_Classification;
