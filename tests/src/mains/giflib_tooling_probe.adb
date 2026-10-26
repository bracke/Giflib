with Ada.Command_Line;

with Project_Tools.Release_Checks;

with Giflib_Tooling;

procedure Giflib_Tooling_Probe is
begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Project_Tools.Release_Checks.Fail
        ("usage: giflib_tooling_probe ROOT");
   end if;
   Giflib_Tooling.Validate (Ada.Command_Line.Argument (1));
end Giflib_Tooling_Probe;
