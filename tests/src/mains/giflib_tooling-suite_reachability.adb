with Ada.Strings.Unbounded;

package body Giflib_Tooling.Suite_Reachability is
   use Ada.Strings.Unbounded;
   package Names renames Giflib_Tooling.Name_Collections;

   function Sequentially_Reachable (Object : State) return Boolean is
     (Object.Sequential_Reachable);

   function Is_Unconditionally_Reachable
     (Object : State; Conditional_Depth : Natural) return Boolean is
     (Conditional_Depth = 0
      and then Object.Sequential_Reachable
      and then not Object.Permanent_Escape
      and then Object.Raises.Is_Empty
      and then Object.Goto_Targets.Is_Empty);

   function Covered_By_Handler
     (Item : Raise_Event; Handler : Handler_Frame) return Boolean is
     (Item.Id <= Handler.Entry_Last_Raise
      and then Item.Scope_Depth >= Handler.Scope_Depth);

   function Has_Unhandled_Blocking_Raise (Object : State) return Boolean is
   begin
      for Item of Object.Raises loop
         if Item.Blocks_Fallthrough then
            declare
               Covered : Boolean := False;
            begin
               for Handler of Object.Handlers loop
                  if Covered_By_Handler (Item, Handler) then
                     Covered := True;
                     exit;
                  end if;
               end loop;
               if not Covered then
                  return True;
               end if;
            end;
         end if;
      end loop;
      return False;
   end Has_Unhandled_Blocking_Raise;

   procedure Reach_Label (Object : in out State; Name : String) is
      Cursor : Natural :=
        (if Object.Goto_Targets.Is_Empty then 0
         else Natural (Object.Goto_Targets.First_Index));
      Reached : Boolean := False;
   begin
      while Cursor > 0
        and then Cursor <= Natural (Object.Goto_Targets.Last_Index)
      loop
         if To_String (Object.Goto_Targets (Positive (Cursor))) = Name then
            Object.Goto_Targets.Delete (Positive (Cursor));
            Reached := True;
         else
            Cursor := Cursor + 1;
         end if;
      end loop;
      if Reached then
         Object.Sequential_Reachable := True;
      end if;
   end Reach_Label;

   procedure Record_Return
     (Object : in out State; Conditional_Depth : Natural) is
   begin
      if not Object.Sequential_Reachable then
         return;
      end if;
      Object.Permanent_Escape := True;
      if Conditional_Depth = 0 then
         Object.Sequential_Reachable := False;
      end if;
   end Record_Return;

   procedure Record_Raise
     (Object : in out State;
      Scope_Depth : Natural;
      Conditional_Depth : Natural) is
   begin
      if not Object.Sequential_Reachable then
         return;
      end if;
      Object.Next_Raise_Id := Object.Next_Raise_Id + 1;
      Object.Raises.Append
        (Raise_Event'
           (Id => Object.Next_Raise_Id,
            Scope_Depth => Scope_Depth,
            Blocks_Fallthrough => Conditional_Depth = 0));
      if Conditional_Depth = 0 then
         Object.Sequential_Reachable := False;
      end if;
   end Record_Raise;

   procedure Record_Goto
     (Object : in out State;
      Name : String;
      Conditional_Depth : Natural) is
   begin
      if not Object.Sequential_Reachable then
         return;
      end if;
      if Conditional_Depth = 0 then
         Object.Sequential_Reachable := False;
      end if;
      if not Names.Contains (Object.Goto_Targets, Name) then
         Object.Goto_Targets.Append (To_Unbounded_String (Name));
      end if;
   end Record_Goto;

   procedure Start_Exception_Handler
     (Object : in out State; Scope_Depth : Natural)
   is
      Has_Raise : Boolean := False;
   begin
      for Item of Object.Raises loop
         if Item.Scope_Depth >= Scope_Depth then
            Has_Raise := True;
            exit;
         end if;
      end loop;
      if Has_Raise then
         Object.Handlers.Append
           (Handler_Frame'
              (Scope_Depth => Scope_Depth,
               Entry_Last_Raise => Object.Next_Raise_Id,
               Catches_All => False,
               Normal_Fallthrough => Object.Sequential_Reachable));
         Object.Sequential_Reachable := True;
      end if;
   end Start_Exception_Handler;

   procedure Catch_All (Object : in out State) is
      Item : Handler_Frame;
   begin
      if not Object.Handlers.Is_Empty then
         Item := Object.Handlers.Last_Element;
         Item.Catches_All := True;
         Object.Handlers.Replace_Element (Object.Handlers.Last_Index, Item);
      end if;
   end Catch_All;

   procedure Finish_Scope
     (Object : in out State; Scope_Depth : Natural)
   is
      Handler : Handler_Frame;
      Cursor : Natural;
   begin
      if Object.Handlers.Is_Empty
        or else Object.Handlers.Last_Element.Scope_Depth /= Scope_Depth
      then
         return;
      end if;
      Handler := Object.Handlers.Last_Element;
      if Handler.Catches_All then
         Cursor :=
           (if Object.Raises.Is_Empty then 0
            else Natural (Object.Raises.First_Index));
         while Cursor > 0
           and then Cursor <= Natural (Object.Raises.Last_Index)
         loop
            if Covered_By_Handler
              (Object.Raises (Positive (Cursor)), Handler)
            then
               Object.Raises.Delete (Positive (Cursor));
            else
               Cursor := Cursor + 1;
            end if;
         end loop;
      end if;
      Object.Handlers.Delete_Last;
      Object.Sequential_Reachable :=
        (Handler.Catches_All or else Handler.Normal_Fallthrough)
        and then not Has_Unhandled_Blocking_Raise (Object);
   end Finish_Scope;
end Giflib_Tooling.Suite_Reachability;
