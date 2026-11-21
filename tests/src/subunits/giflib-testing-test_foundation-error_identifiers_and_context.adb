separate (Giflib.Testing.Test_Foundation)
procedure Error_Identifiers_And_Context (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Context : constant Giflib.Errors.Diagnostic_Context :=
     (Source_Position => Giflib.Errors.Source_Position_At (31),
      Destination_Position => Giflib.Errors.Destination_Position_At (7),
      Block => Giflib.Image_Data_Block,
      Extension_Label => Giflib.Errors.Extension_Label_At (16#F9#),
      Frame => Giflib.Errors.Frame_At (4),
      LZW => Giflib.Errors.LZW_At (299, 9, 17),
      Expected => 12,
      Actual => 13,
      Limit => Giflib.LZW_Work_Limit,
      Underlying_Code => Giflib.Errors.Underlying_Code_At (5));
   Item : constant Giflib.Errors.Error := Giflib.Errors.Make (Giflib.Errors.LZW_Invalid_Code, Context);
   Zero_Position : constant Giflib.Errors.Error :=
     Giflib.Errors.Make
       (Giflib.Errors.Invalid_Block,
        (Source_Position => Giflib.Errors.Source_Position_At (0),
         Frame => Giflib.Errors.Frame_At (0),
         others => <>));
   Absent_Positions : constant Giflib.Errors.Error :=
     Giflib.Errors.Make
       (Giflib.Errors.Invalid_Block,
        (Frame => (Present => False),
         others => <>));
   Absent_Warning_Positions : constant Giflib.Errors.Warning :=
     Giflib.Errors.Make_Warning
       (Giflib.Errors.Generic_Warning,
        Giflib.Errors.Informational,
        (Frame => (Present => False),
         others => <>));
begin
   for Code in Giflib.Errors.Error_Code loop
      Assert (Giflib.Errors.Identifier_For (Code)'Length > 4, "empty or malformed stable identifier");
   end loop;
   Assert (Giflib.Errors.Identifier_For (Giflib.Errors.Invalid_Signature) = "gif.invalid_signature",
           "signature identifier changed");
   Assert (Giflib.Errors.Identifier_For (Giflib.Errors.Limit_Exceeded) = "gif.limit.exceeded",
           "limit identifier changed");
   Assert
     (Giflib.Errors.Identifier_For (Giflib.Errors.Allocation_Failed) =
        "gif.allocation.failed",
      "allocation identifier changed");
   Assert
     (Item.Context.Source_Position.Value = 31
      and then Item.Context.Destination_Position.Value = 7,
      "offset context was lost");
   Assert
     (Item.Context.Source_Position.State = Giflib.Errors.Position_Available
      and then Item.Context.Destination_Position.State =
        Giflib.Errors.Position_Available
      and then Item.Context.Frame.Present,
      "nonzero diagnostic positions were not marked present");
   Assert
     (Zero_Position.Context.Source_Position.State =
        Giflib.Errors.Position_Available
      and then Zero_Position.Context.Source_Position.Value = 0
      and then Zero_Position.Context.Frame.Present
      and then Zero_Position.Context.Frame.Value = 0,
      "zero-valued diagnostic positions cannot be represented");
   Assert
     (Absent_Positions.Context.Source_Position.State =
        Giflib.Errors.Position_Not_Checked
      and then Absent_Positions.Context.Destination_Position.State =
        Giflib.Errors.Position_Not_Checked
      and then not Absent_Positions.Context.Frame.Present,
      "diagnostic presence was inferred from field values");
   Assert
     (Absent_Warning_Positions.Context.Source_Position.State =
        Giflib.Errors.Position_Not_Checked
      and then Absent_Warning_Positions.Context.Destination_Position.State =
        Giflib.Errors.Position_Not_Checked
      and then not Absent_Warning_Positions.Context.Frame.Present,
      "warning presence was inferred from field values");
   Assert (Item.Context.LZW.Present and then Item.Context.LZW.Code_Value = 299,
           "LZW context was lost");
   Assert (Item.Context.Limit = Giflib.LZW_Work_Limit, "limit context was lost");
end Error_Identifiers_And_Context;

