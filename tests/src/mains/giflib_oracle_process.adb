package body Giflib_Oracle_Process is
   use Ada.Strings.Unbounded;
   package Processes renames Project_Tools.Processes;

   function Create (Root, Program : String) return Runner is
     (Root => To_Unbounded_String (Root),
      Program => To_Unbounded_String (Program));

   procedure Run
     (Object : Runner;
      Operation : String;
      Args : Processes.Argument_Vectors.Vector) is
   begin
      Processes.Run
        (Operation, To_String (Object.Root), To_String (Object.Program), Args,
         Quiet => True);
   end Run;

   function Capture
     (Object : Runner;
      Operation : String;
      Args : Processes.Argument_Vectors.Vector) return String
   is
      Output : Unbounded_String;
   begin
      Processes.Run
        (Operation, To_String (Object.Root), To_String (Object.Program), Args,
         Output, Quiet => True);
      return To_String (Output);
   end Capture;
end Giflib_Oracle_Process;
