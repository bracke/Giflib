with Ada.Strings.Unbounded;
with Project_Tools.Processes;

package Giflib_Oracle_Process is
   type Runner (<>) is private;

   function Create (Root, Program : String) return Runner;

   procedure Run
     (Object : Runner;
      Operation : String;
      Args : Project_Tools.Processes.Argument_Vectors.Vector);

   function Capture
     (Object : Runner;
      Operation : String;
      Args : Project_Tools.Processes.Argument_Vectors.Vector) return String;
private
   type Runner is record
      Root : Ada.Strings.Unbounded.Unbounded_String;
      Program : Ada.Strings.Unbounded.Unbounded_String;
   end record;
end Giflib_Oracle_Process;
