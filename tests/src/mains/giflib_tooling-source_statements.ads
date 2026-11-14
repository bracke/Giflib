with Giflib_Tooling.Source_Tokens;

private package Giflib_Tooling.Source_Statements is
   package Source renames Giflib_Tooling.Source_Tokens;

   procedure Scan
     (Tokens : Source.Token_Vectors.Vector;
      Process : not null access procedure
        (Statement : Source.Token_Vectors.Vector));
end Giflib_Tooling.Source_Statements;
