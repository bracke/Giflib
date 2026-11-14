separate (Giflib.Testing.Test_Foundation)
procedure Results_Preserve_First_Error (T : in out AUnit.Test_Cases.Test_Case'Class) is
   pragma Unreferenced (T);
   Good : constant Giflib.Results.Result := Giflib.Results.Success;
   Context : constant Giflib.Errors.Diagnostic_Context :=
     (Source_Position => Giflib.Errors.Source_Position_At (19),
      Block => Giflib.Image_Data_Block,
      Frame => Giflib.Errors.Frame_At (3),
      others => <>);
   Expected : constant Giflib.Errors.Error := Giflib.Errors.Make (Giflib.Errors.Truncated_Block, Context);
   Bad : constant Giflib.Results.Result := Giflib.Results.Failure (Expected);
begin
   Assert (Giflib.Results.Status_Of (Good) = Giflib.Results.Ok,
           "success has the wrong status");
   Assert (Giflib.Results.Status_Of (Bad) = Giflib.Results.Failed,
           "failure has the wrong status");
   Assert (Bad.First_Error.Code = Giflib.Errors.Truncated_Block, "failure lost its error code");
   Assert (Bad.First_Error.Context.Source_Position.Value = 19, "failure lost its source offset");
   Assert (Bad.First_Error.Context.Frame.Present
           and then Bad.First_Error.Context.Frame.Value = 3,
           "failure lost its frame ordinal");
end Results_Preserve_First_Error;

