with Ada.Strings.Fixed;

with Giflib_Tooling.Transition_Policy_Call_Data;
with Giflib_Tooling.Transition_Policy_Review_Data;

package body Giflib_Tooling.Transition_Policy_Index.Builders is
   package Calls renames Giflib_Tooling.Transition_Policy_Call_Data;
   package Reviews renames Giflib_Tooling.Transition_Policy_Review_Data;

   function Empty (Session_Prefix : String := "") return Builder is
     (Value =>
        (Session_Prefix => To_Unbounded_String (Session_Prefix), others => <>),
      others => <>);

   procedure Include_Qualifier (Object : in out Builder; Callee : String) is
      Dot : constant Natural := Ada.Strings.Fixed.Index (Callee, ".");
   begin
      if Dot > Callee'First then
         Object.Value.Trusted_Qualifiers.Include
           (Callee (Callee'First .. Dot - 1));
      end if;
   end Include_Qualifier;

   procedure Add_Global_Call (Object : in out Builder; Callee : String) is
   begin
      if Object.Value.Global_Calls.Contains (Callee) then
         Object.Duplicate_Global_Call := True;
      else
         Object.Value.Global_Calls.Insert (Callee);
         Include_Qualifier (Object, Callee);
      end if;
   end Add_Global_Call;

   procedure Add_Family_Call
     (Object : in out Builder; Unit_Prefix : String; Callee : String)
   is
      Key : constant Family_Call_Key := Family_Key (Unit_Prefix, Callee);
   begin
      if Unit_Prefix = "" or else Object.Value.Family_Calls.Contains (Key) then
         Object.Duplicate_Family_Call := True;
      else
         Object.Value.Family_Calls.Insert (Key);
         Object.Value.Family_Prefixes.Include (Unit_Prefix);
         Include_Qualifier (Object, Callee);
      end if;
   end Add_Family_Call;

   procedure Add_Reviewed_Alias
     (Object : in out Builder;
      Unit_Name : String;
      Alias_Name : String;
      Target : String)
   is
      Key : constant Alias_Key := Reviewed_Alias_Key (Unit_Name, Alias_Name);
   begin
      if Object.Value.Reviewed_Aliases.Contains (Key) then
         Object.Duplicate_Alias := True;
      else
         Object.Value.Reviewed_Aliases.Insert
           (Key, To_Unbounded_String (Target));
      end if;
   end Add_Reviewed_Alias;

   procedure Finish
     (Object : Builder;
      Value : out Index;
      Duplicate : out Duplicate_Kind) is
   begin
      if Object.Duplicate_Global_Call then
         Duplicate := Duplicate_Global_Call;
      elsif Object.Duplicate_Family_Call then
         Duplicate := Duplicate_Family_Call;
      elsif Object.Duplicate_Alias then
         Duplicate := Duplicate_Alias;
      else
         Duplicate := No_Duplicate;
      end if;
      Value := Object.Value;
   end Finish;

   procedure Build
     (Value : out Index;
      Duplicate : out Duplicate_Kind)
   is
      Result : Builder := Empty (Calls.Session_Prefix);
      procedure Add_Global (Callee : String) is
      begin
         Add_Global_Call (Result, Callee);
      end Add_Global;
      procedure Add_Family (Unit_Prefix : String; Callee : String) is
      begin
         Add_Family_Call (Result, Unit_Prefix, Callee);
      end Add_Family;
      procedure Add_Alias
        (Unit_Name : String; Alias_Name : String; Target : String) is
      begin
         Add_Reviewed_Alias (Result, Unit_Name, Alias_Name, Target);
      end Add_Alias;
   begin
      Result.Value.Trusted_Qualifiers.Insert ("session_transitions");
      Calls.Visit_Global_Calls (Add_Global'Access);
      Calls.Visit_Family_Calls (Add_Family'Access);
      Reviews.Visit_Reviewed_Aliases (Add_Alias'Access);
      Finish (Result, Value, Duplicate);
   end Build;
end Giflib_Tooling.Transition_Policy_Index.Builders;
