package body Giflib_Tooling.Transition_Policy_Index is
   use type Ada.Containers.Hash_Type;

   function Hash_Pair (Left : String; Right : String)
      return Ada.Containers.Hash_Type is
     (Ada.Strings.Hash (Left) * 31 xor Ada.Strings.Hash (Right));
   function Hash (Item : Family_Call_Key) return Ada.Containers.Hash_Type is
     (Hash_Pair (To_String (Item.Unit_Name), To_String (Item.Callee)));
   function Hash (Item : Alias_Key) return Ada.Containers.Hash_Type is
     (Hash_Pair
        (To_String (Item.Unit_Name), To_String (Item.Alias_Name)));

   function Family_Key
     (Unit_Name : String; Callee : String) return Family_Call_Key is
     ((To_Unbounded_String (Unit_Name), To_Unbounded_String (Callee)));
   function Reviewed_Alias_Key
     (Unit_Name : String; Alias_Name : String) return Alias_Key is
     ((To_Unbounded_String (Unit_Name), To_Unbounded_String (Alias_Name)));

   function Is_Global_Allowed_Call
     (Object : Index; Callee : String) return Boolean is
     (Object.Global_Calls.Contains (Callee));
   function Allowed_Family
     (Object : Index; Callee : String; Unit_Name : String)
      return Family_Match
   is
   begin
      for Prefix of Object.Family_Prefixes loop
         declare
            Is_Member : constant Boolean :=
              Unit_Name = Prefix & ".adb"
              or else
                (Unit_Name'Length > Prefix'Length
                 and then Unit_Name
                   (Unit_Name'First .. Unit_Name'First + Prefix'Length - 1) =
                     Prefix
                 and then Unit_Name (Unit_Name'First + Prefix'Length) = '-');
         begin
            if Is_Member
              and then Object.Family_Calls.Contains
                (Family_Key (Prefix, Callee))
            then
               return
                 (Found => True, Prefix => To_Unbounded_String (Prefix));
            end if;
         end;
      end loop;
      return (Found => False);
   end Allowed_Family;
   function Is_Allowed_Call
     (Object : Index; Callee : String; Unit_Name : String) return Boolean
   is
      Prefix : constant String := To_String (Object.Session_Prefix);
   begin
      return
        (Prefix'Length > 0
         and then Callee'Length > Prefix'Length
         and then Callee (Callee'First .. Callee'First + Prefix'Length - 1) =
           Prefix)
        or else Is_Global_Allowed_Call (Object, Callee)
        or else Allowed_Family (Object, Callee, Unit_Name).Found;
   end Is_Allowed_Call;
   function Is_Trusted_Qualifier
     (Object : Index; Name : String) return Boolean is
     (Object.Trusted_Qualifiers.Contains (Name));
   function Is_Reviewed_Alias
     (Object : Index;
      Unit_Name : String;
      Alias_Name : String;
      Target : String) return Boolean
   is
      Key : constant Alias_Key := Reviewed_Alias_Key (Unit_Name, Alias_Name);
   begin
      return Object.Reviewed_Aliases.Contains (Key)
        and then To_String (Object.Reviewed_Aliases.Element (Key)) = Target;
   end Is_Reviewed_Alias;
end Giflib_Tooling.Transition_Policy_Index;
