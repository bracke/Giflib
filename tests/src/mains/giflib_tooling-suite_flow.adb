with Giflib_Tooling.Suite_Flow_Classification;
with Giflib_Tooling.Suite_Flow_Ranges;
with Giflib_Tooling.Suite_Flow_State;

package body Giflib_Tooling.Suite_Flow is
   package Flow_State renames Giflib_Tooling.Suite_Flow_State;
   package Classification renames
     Giflib_Tooling.Suite_Flow_Classification;
   package Model renames Giflib_Tooling.Source_Tokens;
   package Range_Analysis renames Giflib_Tooling.Scope_Analysis;
   package Range_Tracking renames Giflib_Tooling.Suite_Flow_Ranges;
   package Syntax renames Giflib_Tooling.Source_Events;

   function Analyze
     (Tokens : Model.Token_Vectors.Vector;
      Events : Syntax.Structural_Event_Vectors.Vector;
      Ranges : Range_Analysis.Subprogram_Range_Vectors.Vector;
      Selection_First : Natural;
      Body_First : Natural;
      Last : Natural) return Flow_Map
   is
      type Optional_Event_Cursor (Present : Boolean := False) is record
         case Present is
            when True =>
               Value : Positive;
            when False =>
               null;
         end case;
      end record;
      Nested : Boolean_Vectors.Vector;
      Unconditional : Boolean_Vectors.Vector;
      Range_Tracker : Range_Tracking.Tracker;
      Event_Cursor : Optional_Event_Cursor :=
        (if Events.Is_Empty
         then (Present => False)
         else (Present => True, Value => Events.First_Index));
      State : Flow_State.State;

      procedure Advance_Event is
      begin
         if not Event_Cursor.Present then
            return;
         elsif Event_Cursor.Value = Events.Last_Index then
            Event_Cursor := (Present => False);
         else
            Event_Cursor.Value := Event_Cursor.Value + 1;
         end if;
      end Advance_Event;
   begin
      if Tokens.Is_Empty
        or else Selection_First = 0
        or else Selection_First < Natural (Tokens.First_Index)
        or else Last > Natural (Tokens.Last_Index)
        or else Last <= Selection_First
        or else Body_First < Selection_First
        or else Body_First > Last
      then
         return (Valid => False);
      end if;
      Range_Tracking.Initialize (Range_Tracker, Ranges);
      while Event_Cursor.Present
        and then Events (Event_Cursor.Value).Token_Index < Selection_First
      loop
         Advance_Event;
      end loop;
      for Index in Positive (Selection_First) .. Positive (Last) loop
         while Event_Cursor.Present
           and then Events (Event_Cursor.Value).Token_Index = Index
         loop
            Flow_State.Observe_Event
              (State, Events (Event_Cursor.Value));
            Advance_Event;
         end loop;
         declare
            Token_Event : constant Classification.Flow_Event :=
              Classification.Classify (Tokens, Index);
         begin
            Nested.Append
              (Range_Tracking.Is_Nested
                 (Range_Tracker, Ranges, Index, Positive (Selection_First)));
            Unconditional.Append
              (Flow_State.Step
                 (State, Token_Event,
                  Eligible => Index > Body_First
                    and then Index < Last
                    and then not Nested.Last_Element));
         end;
      end loop;
      return
        (Valid => True,
         First => Positive (Selection_First),
         Nested => Nested,
         Unconditional => Unconditional);
   end Analyze;

   function In_Range (Map : Flow_Map; Index : Positive) return Boolean is
     (Map.Valid
      and then Index >= Map.First
      and then Index - Map.First < Natural (Map.Nested.Length));

   function Is_Nested (Map : Flow_Map; Index : Positive) return Boolean is
     (In_Range (Map, Index)
      and then Map.Nested (Positive (Index - Map.First + 1)));

   function Is_Unconditional
     (Map : Flow_Map; Index : Positive) return Boolean is
     (In_Range (Map, Index)
      and then Map.Unconditional (Positive (Index - Map.First + 1)));
end Giflib_Tooling.Suite_Flow;
