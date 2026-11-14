package Giflib_Tooling.Transition_Policy_Index.Builders is
   type Builder is private;
   type Duplicate_Kind is
     (No_Duplicate, Duplicate_Global_Call, Duplicate_Family_Call,
      Duplicate_Alias);

   function Empty (Session_Prefix : String := "") return Builder;
   procedure Add_Global_Call (Object : in out Builder; Callee : String);
   procedure Add_Family_Call
     (Object : in out Builder; Unit_Prefix : String; Callee : String);
   procedure Add_Reviewed_Alias
     (Object : in out Builder;
      Unit_Name : String;
      Alias_Name : String;
      Target : String);
   procedure Finish
     (Object : Builder;
      Value : out Index;
      Duplicate : out Duplicate_Kind);
   procedure Build
     (Value : out Index;
      Duplicate : out Duplicate_Kind);

private
   type Builder is record
      Value : Index;
      Duplicate_Global_Call : Boolean := False;
      Duplicate_Family_Call : Boolean := False;
      Duplicate_Alias : Boolean := False;
   end record;
end Giflib_Tooling.Transition_Policy_Index.Builders;
