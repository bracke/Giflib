
package body Giflib_Tooling.Source_Statements is

   procedure Scan
     (Tokens : Source.Token_Vectors.Vector;
      Process : not null access procedure
        (Statement : Source.Token_Vectors.Vector))
   is
      Statement : Source.Token_Vectors.Vector;
   begin
      for Token of Tokens loop
         if Source.Image (Token) = ";" then
            if not Statement.Is_Empty then
               Process (Statement);
               Statement.Clear;
            end if;
         else
            Statement.Append (Token);
         end if;
      end loop;
      if not Statement.Is_Empty then
         Process (Statement);
      end if;
   end Scan;
end Giflib_Tooling.Source_Statements;
