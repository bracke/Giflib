private package Giflib_Tooling.Mutation_Sources is
   procedure Replace_Text
     (Path : String; Before : String; After : String);
   function Reset_Subunit
     (Declarations : String;
      Statements : String;
      Context_Clauses : String := "") return String;
end Giflib_Tooling.Mutation_Sources;
