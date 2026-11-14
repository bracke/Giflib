with Giflib_Tooling.Session_Types;

private package Giflib_Tooling.Session_Iterable_Test_Support is
   package Semantics renames Giflib_Tooling.Session_Types;

   procedure Expect_Item
     (Text : String; Fragment : String; Present : Boolean; Message : String);
   function Has_Item
     (Text : String;
      Context : Semantics.Type_Classification_Vectors.Vector) return Boolean;
end Giflib_Tooling.Session_Iterable_Test_Support;
