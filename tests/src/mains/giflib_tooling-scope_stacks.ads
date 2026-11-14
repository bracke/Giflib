with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

private package Giflib_Tooling.Scope_Stacks is
   generic
      type Kind_Type is (<>);
      Record_Kind : Kind_Type;
      type Metadata_Type is private;
      Default_Metadata : Metadata_Type;
   package Models is
      type Frame is record
         Kind : Kind_Type;
         Name : Ada.Strings.Unbounded.Unbounded_String;
         Metadata : Metadata_Type := Default_Metadata;
      end record;

      type Optional_Frame (Present : Boolean := False) is record
         case Present is
            when True =>
               Value : Frame;
            when False =>
               null;
         end case;
      end record;

      type Stack is private;

      function Depth (Object : Stack) return Natural;
      function Top (Object : Stack) return Optional_Frame;
      procedure Push
        (Object : in out Stack;
         Kind : Kind_Type;
         Name : Ada.Strings.Unbounded.Unbounded_String;
         Metadata : Metadata_Type := Default_Metadata;
         Maximum_Depth : Natural := Natural'Last);
      procedure Close
        (Object : in out Stack;
         Ending_Name : Ada.Strings.Unbounded.Unbounded_String;
         Result : out Optional_Frame);
      procedure Close_Record
        (Object : in out Stack; Result : out Optional_Frame);
      procedure Set_Top_Metadata
        (Object : in out Stack; Metadata : Metadata_Type);
   private
      package Frame_Vectors is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => Frame);

      type Stack is record
         Items : Frame_Vectors.Vector;
      end record;
   end Models;
end Giflib_Tooling.Scope_Stacks;
