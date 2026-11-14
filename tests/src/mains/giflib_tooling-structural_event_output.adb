with Giflib_Tooling.Model_Storage;

package body Giflib_Tooling.Structural_Event_Output is
   package Storage_Budgets renames Giflib_Tooling.Model_Storage_Budgets;
   package Model_Storage renames Giflib_Tooling.Model_Storage;
   package Recognition renames Giflib_Tooling.Structural_Recognition;
   package Scopes renames Recognition.Scopes;
   package Types renames Giflib_Tooling.Source_Events;
   use Types;

   procedure Require_Capacity
     (Events : Structural_Event_Vectors.Vector; Maximum_Events : Natural) is
   begin
      if Natural (Events.Length) >= Maximum_Events then
         raise Input_Error with "structural event limit exceeded";
      end if;
   end Require_Capacity;

   procedure Append_Terminal
     (Events : in out Structural_Event_Vectors.Vector;
      Index : Positive;
      Kind : Terminal_Event_Kind;
      Maximum_Events : Natural;
      Storage : in out Storage_Budgets.Budget) is
   begin
      Require_Capacity (Events, Maximum_Events);
      Model_Storage.Charge_Terminal_Event (Storage);
      Events.Append (Structural_Event'(Kind => Kind, Token_Index => Index));
   end Append_Terminal;

   procedure Append_Scope_End
     (Events : in out Structural_Event_Vectors.Vector;
      Index : Positive;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Maximum_Events : Natural;
      Storage : in out Storage_Budgets.Budget) is
   begin
      Require_Capacity (Events, Maximum_Events);
      Model_Storage.Charge_Named_Event (Storage, Name);
      Events.Append
        (Structural_Event'
           (Kind => Scope_End, Token_Index => Index, Ending_Name => Name));
   end Append_Scope_End;

   procedure Append_Subprogram
     (Events : in out Structural_Event_Vectors.Vector;
      Recognition_State : in out Recognition.Stack;
      Index : Positive;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Info : Giflib_Tooling.Structural_Subprograms.Subprogram_Info;
      Maximum_Events : Natural;
      Maximum_Depth : Natural;
      Storage : in out Storage_Budgets.Budget) is
   begin
      Require_Capacity (Events, Maximum_Events);
      Model_Storage.Charge_Subprogram_Event
        (Storage, Name, Info.Profile);
      Events.Append
        (Structural_Event'
           (Kind => Subprogram_Start, Token_Index => Index,
            Subprogram_Name => Name, Header => Info));
      if Info.Introduces_Scope then
         Recognition.Push
           (Recognition_State, Scopes.Subprogram_Scope, Name,
            Maximum_Depth => Maximum_Depth);
      end if;
   end Append_Subprogram;

   procedure Append_Package
     (Events : in out Structural_Event_Vectors.Vector;
      Recognition_State : in out Recognition.Stack;
      Index : Positive;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Introduces_Scope : Boolean;
      Is_Body : Boolean;
      Maximum_Events : Natural;
      Maximum_Depth : Natural;
      Storage : in out Storage_Budgets.Budget) is
   begin
      Require_Capacity (Events, Maximum_Events);
      Model_Storage.Charge_Named_Event (Storage, Name);
      Events.Append
        (Structural_Event'
           (Kind => Package_Start, Token_Index => Index,
            Package_Name => Name,
            Package_Introduces_Scope => Introduces_Scope,
            Package_Is_Body => Is_Body));
      if Introduces_Scope then
         Recognition.Push
           (Recognition_State, Scopes.Package_Scope, Name,
            Maximum_Depth => Maximum_Depth);
      end if;
   end Append_Package;

   procedure Append_Program
     (Events : in out Structural_Event_Vectors.Vector;
      Recognition_State : in out Recognition.Stack;
      Index : Positive;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Maximum_Events : Natural;
      Maximum_Depth : Natural;
      Storage : in out Storage_Budgets.Budget) is
   begin
      Require_Capacity (Events, Maximum_Events);
      Model_Storage.Charge_Named_Event (Storage, Name);
      Events.Append
        (Structural_Event'
           (Kind => Program_Start, Token_Index => Index,
            Program_Name => Name));
      Recognition.Push
        (Recognition_State, Scopes.Program_Scope, Name,
         Maximum_Depth => Maximum_Depth);
   end Append_Program;

   procedure Append_Block
     (Events : in out Structural_Event_Vectors.Vector;
      Recognition_State : in out Recognition.Stack;
      Index : Positive;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Body_Started : Boolean;
      Maximum_Events : Natural;
      Maximum_Depth : Natural;
      Storage : in out Storage_Budgets.Budget) is
   begin
      Require_Capacity (Events, Maximum_Events);
      Model_Storage.Charge_Named_Event (Storage, Name);
      Events.Append
        (Structural_Event'
           (Kind => Block_Start, Token_Index => Index, Block_Name => Name));
      Recognition.Push
        (Recognition_State, Scopes.Block_Scope, Name,
         Body_Started => Body_Started, Maximum_Depth => Maximum_Depth);
   end Append_Block;

   procedure Append_Record
     (Events : in out Structural_Event_Vectors.Vector;
      Recognition_State : in out Recognition.Stack;
      Index : Positive;
      Name : Ada.Strings.Unbounded.Unbounded_String;
      Maximum_Events : Natural;
      Maximum_Depth : Natural;
      Storage : in out Storage_Budgets.Budget) is
   begin
      Require_Capacity (Events, Maximum_Events);
      Model_Storage.Charge_Named_Event (Storage, Name);
      Events.Append
        (Structural_Event'
           (Kind => Record_Start, Token_Index => Index, Record_Name => Name));
      Recognition.Push
        (Recognition_State, Scopes.Record_Scope, Name,
         Body_Started => True, Maximum_Depth => Maximum_Depth);
   end Append_Record;
end Giflib_Tooling.Structural_Event_Output;
