with Ada.Strings.Unbounded;

package body Giflib_Tooling.Transition_Policy_Review_Data is
   use Ada.Strings.Unbounded;

   type Alias_Review is record
      Unit_Name : Unbounded_String;
      Alias_Name : Unbounded_String;
      Target : Unbounded_String;
   end record;

   type Alias_Review_Array is array (Positive range <>) of Alias_Review;

   function Alias_Item
     (Unit_Name : String; Alias_Name : String; Target : String)
      return Alias_Review is
     ((To_Unbounded_String (Unit_Name), To_Unbounded_String (Alias_Name),
       To_Unbounded_String (Target)));

   Reviewed_Aliases : constant Alias_Review_Array :=
     [Alias_Item
        ("giflib-encoding-frame_pipeline.adb", "geometry_arithmetic",
         "internal.geometry_arithmetic"),
      Alias_Item
        ("giflib-encoding-request_validation.adb", "geometry_arithmetic",
         "internal.geometry_arithmetic"),
      Alias_Item
        ("giflib-encoding-request_validation.adb", "session_arithmetic",
         "internal.session_arithmetic"),
      Alias_Item
        ("giflib-decoding-extensions-transport.adb", "arithmetic",
         "internal.metadata_arithmetic")];

   procedure Visit_Reviewed_Aliases
     (Process : not null access procedure
        (Unit_Name : String; Alias_Name : String; Target : String)) is
   begin
      for Item of Reviewed_Aliases loop
         Process
           (To_String (Item.Unit_Name), To_String (Item.Alias_Name),
            To_String (Item.Target));
      end loop;
   end Visit_Reviewed_Aliases;
end Giflib_Tooling.Transition_Policy_Review_Data;
