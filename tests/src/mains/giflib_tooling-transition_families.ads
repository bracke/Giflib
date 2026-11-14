with Ada.Strings.Unbounded;

with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Session_Identity;

private package Giflib_Tooling.Transition_Families is
   type Family_Definition is record
      Prefix : Ada.Strings.Unbounded.Unbounded_String;
      Owner : Ada.Strings.Unbounded.Unbounded_String;
      Specification : Ada.Strings.Unbounded.Unbounded_String;
      Type_Name : Ada.Strings.Unbounded.Unbounded_String;
      Target : Giflib_Tooling.Session_Identity.Target;
      Exempt_Fields : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
   end record;

   procedure Visit
     (Process : not null access procedure (Item : Family_Definition));
end Giflib_Tooling.Transition_Families;
