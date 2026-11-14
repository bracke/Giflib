with Giflib_Tooling.Text_Case;

package body Giflib_Tooling.Declaration_Analysis is
   use type Source.Token_Kind;
   package Text_Case renames Giflib_Tooling.Text_Case;

   procedure Inspect_Record_At
     (Tokens : Source.Token_Vectors.Vector;
      Record_Index : Positive;
      Process : not null access procedure
        (Name : Ada.Strings.Unbounded.Unbounded_String;
         Type_First : Positive;
         Type_Last : Positive))
   is
      Declaration_First : Positive := Record_Index + 1;
      Index : Positive := Record_Index + 1;
      Depth : Natural := 1;
   begin
      if Tokens.Is_Empty
        or else Record_Index not in Tokens.First_Index .. Tokens.Last_Index
        or else Source.Image (Tokens (Record_Index)) /= "record"
        or else Record_Index = Tokens.Last_Index
      then
         return;
      end if;
      while Index <= Tokens.Last_Index loop
         if Source.Image (Tokens (Index)) = "end"
           and then Index < Tokens.Last_Index
           and then Source.Image (Tokens (Index + 1)) = "record"
         then
            Depth := Depth - 1;
            exit when Depth = 0;
            Index := Index + 1;
         elsif Source.Image (Tokens (Index)) = "record"
           and then (Index = Tokens.First_Index
                     or else Source.Image (Tokens (Index - 1)) /= "null")
         then
            Depth := Depth + 1;
         elsif Depth = 1 and then Source.Image (Tokens (Index)) = ";" then
            declare
               Colon : Source.Optional_Position;
               Type_Last : Natural := Index - 1;
               Parentheses : Natural := 0;
               First_Name : Source.Optional_Position;
            begin
               if Declaration_First < Index then
                  for Cursor in Declaration_First .. Index - 1 loop
                     if Source.Image (Tokens (Cursor)) = ":" then
                        Colon := (Present => True, Value => Cursor);
                        exit;
                     end if;
                  end loop;
               end if;
               if Colon.Present
                 and then Colon.Value > Declaration_First
                 and then Colon.Value < Index - 1
               then
                  if Source.Kind_Of (Tokens (Colon.Value - 1)) = Source.Identifier then
                     First_Name := (Present => True, Value => Colon.Value - 1);
                     while First_Name.Value >= Declaration_First + 2
                       and then Source.Image
                         (Tokens (First_Name.Value - 1)) = ","
                       and then
                         Source.Kind_Of (Tokens (First_Name.Value - 2)) =
                           Source.Identifier
                     loop
                        First_Name :=
                          (Present => True, Value => First_Name.Value - 2);
                     end loop;
                  end if;
                  for Cursor in Colon.Value + 1 .. Index - 1 loop
                     if Source.Image (Tokens (Cursor)) = "(" then
                        Parentheses := Parentheses + 1;
                     elsif Source.Image (Tokens (Cursor)) = ")"
                       and then Parentheses > 0
                     then
                        Parentheses := Parentheses - 1;
                     elsif Parentheses = 0
                       and then Source.Image (Tokens (Cursor)) in ":=" | "with"
                     then
                        Type_Last := Cursor - 1;
                        exit;
                     end if;
                  end loop;
                  if First_Name.Present
                    and then Type_Last >= Colon.Value + 1
                  then
                     for Cursor in First_Name.Value .. Colon.Value - 1 loop
                        if Source.Kind_Of (Tokens (Cursor)) = Source.Identifier then
                           Process
                             (Source.Text_Of (Tokens (Cursor)), Colon.Value + 1,
                              Positive (Type_Last));
                        end if;
                     end loop;
                  end if;
               end if;
            end;
            Declaration_First := Index + 1;
         end if;
         Index := Index + 1;
      end loop;
   end Inspect_Record_At;

   procedure Inspect_Record
     (Tokens : Source.Token_Vectors.Vector;
      Type_Name : String;
      Process : not null access procedure
        (Name : Ada.Strings.Unbounded.Unbounded_String;
         Type_First : Positive;
         Type_Last : Positive))
   is
      Target : constant String := Text_Case.Lower (Type_Name);
      Candidate : Ada.Strings.Unbounded.Unbounded_String;
      In_Type : Boolean := False;
      Parentheses : Natural := 0;
   begin
      if Tokens.Is_Empty then
         return;
      end if;
      for Index in Tokens.First_Index .. Tokens.Last_Index loop
         if Source.Image (Tokens (Index)) = "type"
           and then Index < Tokens.Last_Index
           and then Source.Kind_Of (Tokens (Index + 1)) = Source.Identifier
         then
            Candidate := Source.Text_Of (Tokens (Index + 1));
            In_Type := True;
            Parentheses := 0;
         elsif In_Type and then Source.Image (Tokens (Index)) = "(" then
            Parentheses := Parentheses + 1;
         elsif In_Type and then Source.Image (Tokens (Index)) = ")"
           and then Parentheses > 0
         then
            Parentheses := Parentheses - 1;
         elsif In_Type
           and then Parentheses = 0
           and then Source.Image (Tokens (Index)) = "record"
           and then Ada.Strings.Unbounded.To_String (Candidate) = Target
         then
            Inspect_Record_At (Tokens, Index, Process);
            return;
         elsif In_Type
           and then Parentheses = 0
           and then Source.Image (Tokens (Index)) = ";"
         then
            In_Type := False;
            Candidate := Ada.Strings.Unbounded.Null_Unbounded_String;
         end if;
      end loop;
   end Inspect_Record;
end Giflib_Tooling.Declaration_Analysis;
