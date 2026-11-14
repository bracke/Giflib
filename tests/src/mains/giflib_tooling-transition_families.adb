package body Giflib_Tooling.Transition_Families is
   use Ada.Strings.Unbounded;
   function Define
     (Prefix : String;
      Owner : String;
      Specification : String;
      Simple_Type : String;
      Qualified_Type : String;
      Include_Quantizer : Boolean) return Family_Definition
   is
      Exempt_Fields : Giflib_Tooling.Name_Collections.Name_Vectors.Vector;
   begin
      Exempt_Fields.Append (To_Unbounded_String ("resources"));
      if Include_Quantizer then
         Exempt_Fields.Append (To_Unbounded_String ("quantizer_data"));
      end if;
      Exempt_Fields.Append (To_Unbounded_String ("allocation_fault"));
      return
        (Prefix => To_Unbounded_String (Prefix),
         Owner => To_Unbounded_String (Owner),
         Specification => To_Unbounded_String (Specification),
         Type_Name => To_Unbounded_String (Simple_Type),
         Target => Giflib_Tooling.Session_Identity.Create_Known
           (Simple_Type, Qualified_Type),
         Exempt_Fields => Exempt_Fields);
   end Define;

   type Family_Definition_Array is
     array (Positive range <>) of Family_Definition;
   Definitions : constant Family_Definition_Array :=
     [Define
        ("giflib-decoding",
         "giflib-decoding-session_transitions.adb",
         "src/giflib-decoding.ads",
         "decoder",
         "giflib.decoding.decoder",
         Include_Quantizer => False),
      Define
        ("giflib-encoding",
         "giflib-encoding-session_transitions.adb",
         "src/giflib-encoding.ads",
         "encoder",
         "giflib.encoding.encoder",
         Include_Quantizer => True)];

   procedure Visit
     (Process : not null access procedure (Item : Family_Definition)) is
   begin
      for Item of Definitions loop
         Process (Item);
      end loop;
   end Visit;
end Giflib_Tooling.Transition_Families;
