with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Tokens;
with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Session_Analysis_Testing;
with Giflib_Tooling.Session_Identity;
with Giflib_Tooling.Session_Query_Testing;

package body Giflib_Tooling.Session_Iterable_Test_Support is
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Analysis renames Giflib_Tooling.Session_Analysis_Testing;
   package Identity renames Giflib_Tooling.Session_Identity;
   package Queries renames Giflib_Tooling.Session_Query_Testing;

   procedure Expect_Item
     (Text : String; Fragment : String; Present : Boolean; Message : String) is
   begin
      Check.Check
        (Giflib_Tooling.Name_Collections.Contains
           (Queries.Identifiers_At
              (Text, Identity.Create_Known ("Decoder"),
               Check.Position_After (Text, Fragment)),
            "item") = Present,
         Message);
   end Expect_Item;

   function Has_Item
     (Text : String;
      Context : Semantics.Type_Classification_Vectors.Vector) return Boolean
   is
      Found : Boolean := False;
      procedure Capture
        (Statement : Giflib_Tooling.Source_Tokens.Token_Vectors.Vector;
         Session_Names : Giflib_Tooling.Name_Collections.Name_Vectors.Vector)
      is
         pragma Unreferenced (Statement);
      begin
         Found := Found or else Giflib_Tooling.Name_Collections.Contains (Session_Names, "item");
      end Capture;
   begin
      Analysis.Scan
        (Text, Identity.Create_Known ("Decoder"), Context, Capture'Access);
      return Found;
   end Has_Item;
end Giflib_Tooling.Session_Iterable_Test_Support;
