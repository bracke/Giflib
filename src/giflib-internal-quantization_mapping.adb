with Interfaces;
with Giflib.Errors;
with Giflib.Internal.Quantization_Pixels;
with Giflib.Internal.Quantization_Storage.Outcomes;
with Giflib.Internal.Resource_Diagnostics;

package body Giflib.Internal.Quantization_Mapping is
   use type Interfaces.Unsigned_32;
   use type Palettes.RGB_Color;
   package Cache renames Quantization_Storage.Cache_Operations;
   package Outcomes renames Quantization_Storage.Outcomes;
   package Pixels renames Quantization_Pixels;
   use type Outcomes.Storage_Status;

   function Work_Failure
     (Work : Work_Budgets.Meter) return Results.Result is
     (Results.Failure
        (Errors.Make
           (Errors.Limit_Exceeded,
            Resource_Diagnostics.With_Work_Limit
              (Work, Quantization_Work_Limit))));

   function Invariant_Failure return Results.Result is
     (Results.Failure (Errors.Make (Errors.Internal_Invariant_Failed)));

   function Node_Count (Object : Search_Index) return Natural is
     (Object.Count);

   function Component
     (Color : Palettes.RGB_Color; Axis : Color_Axis) return Natural is
     (case Axis is
         when Red_Axis => Natural (Color.Red),
         when Green_Axis => Natural (Color.Green),
         when Blue_Axis => Natural (Color.Blue));

   function Build
     (Output_Palette : Palettes.Palette;
      First : Natural;
      Exclude_Index : Boolean;
      Excluded_Index : Palette_Index;
      Work : in out Work_Budgets.Meter;
      Object : out Search_Index) return Results.Result
   is
      type Value_Array is array (Natural range 0 .. 255) of Palette_Index;
      type Axis_Lists is array (Color_Axis) of Value_Array;
      type Branch_Kind is (Left_Branch, Root_Branch, Right_Branch);
      type Branch_Array is array (Palette_Index) of Branch_Kind;
      Values : Value_Array := [others => 0];
      Lists : Axis_Lists := [others => [others => 0]];
      Scratch : Value_Array := [others => 0];
      Candidate_Count : Natural := 0;
      Value_Count : Natural := 0;
      Accepted : Boolean;

      function Comes_Before
        (Left, Right : Palette_Index;
         Axis : Color_Axis;
         Full_Color_Order : Boolean) return Boolean
      is
         Left_Color : Palettes.RGB_Color renames Output_Palette.Colors (Left);
         Right_Color : Palettes.RGB_Color renames Output_Palette.Colors (Right);
         Left_Component : constant Natural :=
           Component (Left_Color, Axis);
         Right_Component : constant Natural :=
           Component (Right_Color, Axis);
      begin
         if Full_Color_Order then
            return Left_Color.Red < Right_Color.Red
              or else
                (Left_Color.Red = Right_Color.Red
                 and then
                   (Left_Color.Green < Right_Color.Green
                    or else
                      (Left_Color.Green = Right_Color.Green
                       and then
                         (Left_Color.Blue < Right_Color.Blue
                          or else
                            (Left_Color.Blue = Right_Color.Blue
                             and then Natural (Left) < Natural (Right))))));
         end if;
         return Left_Component < Right_Component
           or else (Left_Component = Right_Component
                    and then Natural (Left) < Natural (Right));
      end Comes_Before;

      procedure Sort
        (Items : in out Value_Array;
         Temporary : in out Value_Array;
         First_Position, Last_Position : Natural;
         Axis : Color_Axis;
         Full_Color_Order : Boolean := False)
      is
         procedure Merge_Sort (Left, Right : Natural) is
            Middle : Natural;
            Left_Position, Right_Position, Output_Position : Natural;
         begin
            if Left >= Right then return; end if;
            Middle := Left + (Right - Left) / 2;
            Merge_Sort (Left, Middle);
            Merge_Sort (Middle + 1, Right);
            Left_Position := Left;
            Right_Position := Middle + 1;
            Output_Position := Left;
            while Left_Position <= Middle
              and then Right_Position <= Right
            loop
               if Comes_Before
                 (Items (Left_Position), Items (Right_Position), Axis,
                  Full_Color_Order)
               then
                  Temporary (Output_Position) := Items (Left_Position);
                  Left_Position := Left_Position + 1;
               else
                  Temporary (Output_Position) := Items (Right_Position);
                  Right_Position := Right_Position + 1;
               end if;
               Output_Position := Output_Position + 1;
            end loop;
            while Left_Position <= Middle loop
               Temporary (Output_Position) := Items (Left_Position);
               Left_Position := Left_Position + 1;
               Output_Position := Output_Position + 1;
            end loop;
            while Right_Position <= Right loop
               Temporary (Output_Position) := Items (Right_Position);
               Right_Position := Right_Position + 1;
               Output_Position := Output_Position + 1;
            end loop;
            Items (Left .. Right) := Temporary (Left .. Right);
         end Merge_Sort;
      begin
         Merge_Sort (First_Position, Last_Position);
      end Sort;

      function Add_Subtree
        (Subtree : Axis_Lists;
         Count : Natural) return Node_Id
      is
         Axis : Color_Axis := Red_Axis;
         Greatest_Extent : Natural := 0;
         Middle : Natural;
         Id : Node_Id;
         Value : Palette_Index;
      begin
         if Count = 0 then return 0; end if;
         for Candidate in Color_Axis loop
            declare
               Low : constant Natural := Component
                 (Output_Palette.Colors (Subtree (Candidate) (0)), Candidate);
               High : constant Natural := Component
                 (Output_Palette.Colors
                    (Subtree (Candidate) (Count - 1)), Candidate);
               Extent : constant Natural := High - Low;
            begin
               if Extent > Greatest_Extent then
                  Axis := Candidate;
                  Greatest_Extent := Extent;
               end if;
            end;
         end loop;
         Middle := (Count - 1) / 2;
         Value := Subtree (Axis) (Middle);
         Object.Count := Object.Count + 1;
         Id := Node_Id (Object.Count);
         Object.Nodes (Id) :=
           (Color => Output_Palette.Colors (Value),
            Minimum =>
              (Red => Output_Palette.Colors
                 (Subtree (Red_Axis) (0)).Red,
               Green => Output_Palette.Colors
                 (Subtree (Green_Axis) (0)).Green,
               Blue => Output_Palette.Colors
                 (Subtree (Blue_Axis) (0)).Blue),
            Maximum =>
              (Red => Output_Palette.Colors
                 (Subtree (Red_Axis) (Count - 1)).Red,
               Green => Output_Palette.Colors
                 (Subtree (Green_Axis) (Count - 1)).Green,
               Blue => Output_Palette.Colors
                 (Subtree (Blue_Axis) (Count - 1)).Blue),
            Value => Value, Axis => Axis, Left => 0, Right => 0);
         if Count = 1 then return Id; end if;
         declare
            Branches : Branch_Array;
            Left_Lists : Axis_Lists;
            Right_Lists : Axis_Lists;
            Left_Count, Right_Count : Natural;
         begin
            if Middle > 0 then
               for Position in 0 .. Middle - 1 loop
                  Branches (Subtree (Axis) (Position)) := Left_Branch;
               end loop;
            end if;
            Branches (Value) := Root_Branch;
            if Middle + 1 < Count then
               for Position in Middle + 1 .. Count - 1 loop
                  Branches (Subtree (Axis) (Position)) := Right_Branch;
               end loop;
            end if;
            for Current_Axis in Color_Axis loop
               Left_Count := 0;
               Right_Count := 0;
               for Position in 0 .. Count - 1 loop
                  declare
                     Item : constant Palette_Index :=
                       Subtree (Current_Axis) (Position);
                  begin
                     case Branches (Item) is
                        when Left_Branch =>
                           Left_Lists (Current_Axis) (Left_Count) := Item;
                           Left_Count := Left_Count + 1;
                        when Right_Branch =>
                           Right_Lists (Current_Axis) (Right_Count) := Item;
                           Right_Count := Right_Count + 1;
                        when Root_Branch => null;
                     end case;
                  end;
               end loop;
            end loop;
            Object.Nodes (Id).Left :=
              Add_Subtree (Left_Lists, Middle);
            Object.Nodes (Id).Right :=
              Add_Subtree (Right_Lists, Count - Middle - 1);
         end;
         return Id;
      end Add_Subtree;
   begin
      Object := (others => <>);
      Object.Colors := Output_Palette.Colors;
      if Output_Palette.Length <= First then return Invariant_Failure; end if;
      for I in First .. Output_Palette.Length - 1 loop
         if not (Exclude_Index and then Palette_Index (I) = Excluded_Index) then
            Values (Candidate_Count) := Palette_Index (I);
            Candidate_Count := Candidate_Count + 1;
         end if;
      end loop;
      if Candidate_Count = 0 then return Invariant_Failure; end if;
      declare
         Levels : Natural := 0;
         Remaining : Natural := Candidate_Count;
      begin
         while Remaining > 1 loop
            Levels := Levels + 1;
            Remaining := (Remaining + 1) / 2;
         end loop;
         Work_Budgets.Try_Charge
           (Work,
            Byte_Count (Candidate_Count)
              * Byte_Count (Natural'Max (1, 2 * Levels)),
            Accepted);
         if not Accepted then return Work_Failure (Work); end if;
      end;
      Sort
        (Values, Scratch, 0, Candidate_Count - 1, Red_Axis,
         Full_Color_Order => True);
      for Position in 0 .. Candidate_Count - 1 loop
         declare
            Candidate : constant Palette_Index := Values (Position);
         begin
            if Value_Count = 0
              or else Output_Palette.Colors (Candidate) /=
                Output_Palette.Colors (Values (Value_Count - 1))
            then
               Values (Value_Count) := Candidate;
               Value_Count := Value_Count + 1;
            end if;
         end;
      end loop;
      declare
         Levels : Natural := 0;
         Remaining : Natural := Value_Count;
      begin
         while Remaining > 1 loop
            Levels := Levels + 1;
            Remaining := (Remaining + 1) / 2;
         end loop;
         Work_Budgets.Try_Charge
           (Work,
            Byte_Count (Value_Count)
              * Byte_Count (Natural'Max (1, 4 * Levels)),
            Accepted);
      end;
      if not Accepted then return Work_Failure (Work); end if;
      Lists (Red_Axis) (0 .. Value_Count - 1) :=
        Values (0 .. Value_Count - 1);
      for Axis in Green_Axis .. Blue_Axis loop
         Lists (Axis) (0 .. Value_Count - 1) := Values (0 .. Value_Count - 1);
         Sort (Lists (Axis), Scratch, 0, Value_Count - 1, Axis);
      end loop;
      Object.Root := Add_Subtree (Lists, Value_Count);
      return
        (if Object.Root = 0 then Invariant_Failure else Results.Success);
   end Build;

   function Find
     (State : in out Cache.Cache_State;
      Current_Epoch : Cache.Epoch;
      Color : Palettes.RGB_Color;
      Search : Search_Index;
      Use_Cache : Boolean;
      Hint_Valid : Boolean;
      Hint_Value : Palette_Index;
      Chosen : out Palette_Index;
      Cache_Hit : out Boolean;
      Work_Used : out Byte_Count) return Find_Status
   is
      Key : constant Natural := Pixels.Color_Key (Color);
      Probe_Kind : Cache.Probe_Kind := Cache.Probe_Miss;
      Probe_Value : Palette_Index := 0;
      Probe_Store_Slot : Natural := 0;
      Probe_Work : Byte_Count := 0;
      Best : Palette_Index := 0;
      Best_Distance : Interfaces.Unsigned_32 := Interfaces.Unsigned_32'Last;
      Visited : Natural := 0;
      Status : Outcomes.Storage_Status;

      function Squared
        (DR, DG, DB : Integer) return Interfaces.Unsigned_32 is
        (Interfaces.Unsigned_32 (DR * DR)
         + Interfaces.Unsigned_32 (DG * DG)
         + Interfaces.Unsigned_32 (DB * DB));
      pragma Inline_Always (Squared);

      function Bound_Distance
        (Id : Node_Id) return Interfaces.Unsigned_32 is
         DR, DG, DB : Integer := 0;
      begin
         if Id = 0 then return Interfaces.Unsigned_32'Last; end if;
         declare
            Node : Search_Node renames Search.Nodes (Id);
         begin
            if Color.Red < Node.Minimum.Red then
               DR := Integer (Node.Minimum.Red) - Integer (Color.Red);
            elsif Color.Red > Node.Maximum.Red then
               DR := Integer (Color.Red) - Integer (Node.Maximum.Red);
            end if;
            if Color.Green < Node.Minimum.Green then
               DG := Integer (Node.Minimum.Green) - Integer (Color.Green);
            elsif Color.Green > Node.Maximum.Green then
               DG := Integer (Color.Green) - Integer (Node.Maximum.Green);
            end if;
            if Color.Blue < Node.Minimum.Blue then
               DB := Integer (Node.Minimum.Blue) - Integer (Color.Blue);
            elsif Color.Blue > Node.Maximum.Blue then
               DB := Integer (Color.Blue) - Integer (Node.Maximum.Blue);
            end if;
         end;
         return Squared (DR, DG, DB);
      end Bound_Distance;

      procedure Visit (Id : Node_Id) is
         Distance : Interfaces.Unsigned_32;
         Difference, DR, DG, DB : Integer;
         Near_Node, Far_Node : Node_Id;
      begin
         if Id = 0 then return; end if;
         declare
            Node : Search_Node renames Search.Nodes (Id);
         begin
            Visited := Visited + 1;
            DR := Integer (Color.Red) - Integer (Node.Color.Red);
            DG := Integer (Color.Green) - Integer (Node.Color.Green);
            DB := Integer (Color.Blue) - Integer (Node.Color.Blue);
            Distance := Squared (DR, DG, DB);
            if Distance < Best_Distance
              or else
                (Distance = Best_Distance
                 and then Natural (Node.Value) < Natural (Best))
            then
               Best := Node.Value;
               Best_Distance := Distance;
            end if;
            Difference := Integer (Component (Color, Node.Axis))
              - Integer (Component (Node.Color, Node.Axis));
            if Difference < 0 then
               Near_Node := Node.Left;
               Far_Node := Node.Right;
            else
               Near_Node := Node.Right;
               Far_Node := Node.Left;
            end if;
            Visit (Near_Node);
            if Interfaces.Unsigned_32 (Difference * Difference) <= Best_Distance
              and then Bound_Distance (Far_Node) <= Best_Distance
            then
               Visit (Far_Node);
            end if;
         end;
      end Visit;
   begin
      Chosen := 0;
      Cache_Hit := False;
      Work_Used := 0;
      if Use_Cache then
         Probe_Kind := Cache.Probe_Validated
           (State, Current_Epoch, Key, Probe_Value, Probe_Store_Slot,
            Probe_Work);
         Work_Used := Probe_Work;
         case Probe_Kind is
            when Cache.Probe_Work_Limit | Cache.Probe_Invariant_Failure =>
               return Find_Invariant_Failure;
            when Cache.Probe_Hit =>
               Chosen := Probe_Value;
               Cache_Hit := True;
               return Find_Ready;
            when Cache.Probe_Miss => null;
         end case;
      end if;
      if Search.Root = 0 then return Find_Invariant_Failure; end if;
      if Hint_Valid then
         declare
            Hint_Color : Palettes.RGB_Color renames Search.Colors (Hint_Value);
            DR : constant Integer :=
              Integer (Color.Red) - Integer (Hint_Color.Red);
            DG : constant Integer :=
              Integer (Color.Green) - Integer (Hint_Color.Green);
            DB : constant Integer :=
              Integer (Color.Blue) - Integer (Hint_Color.Blue);
         begin
            Best := Hint_Value;
            Best_Distance := Squared (DR, DG, DB);
            Work_Used := Work_Used + 1;
         end;
      end if;
      --  Pixel_Mapping only supplies a hint returned by the preceding search,
      --  so an exact hint is already the canonical lowest palette index for
      --  duplicate colors.  No tree node can improve a zero distance.
      if Best_Distance /= 0 then
         Visit (Search.Root);
         Work_Used := Work_Used + Byte_Count (Visited);
      end if;
      if Best_Distance = Interfaces.Unsigned_32'Last then
         return Find_Invariant_Failure;
      end if;
      Chosen := Best;
      if Use_Cache then
         Status := Cache.Store
           (State, Current_Epoch, Probe_Store_Slot, Key, Chosen);
      else
         Status := Outcomes.Storage_Ready;
      end if;
      return
        (if Status = Outcomes.Storage_Ready
         then Find_Ready else Find_Invariant_Failure);
   end Find;
end Giflib.Internal.Quantization_Mapping;
