with Giflib.Internal.Quantization_Storage.Cache_Operations;
with Giflib.Internal.Work_Budgets;
with Giflib.Palettes;
with Giflib.Results;

package Giflib.Internal.Quantization_Mapping is
   pragma Preelaborate;

   type Search_Index is private;

   function Node_Count (Object : Search_Index) return Natural;

   function Build
     (Output_Palette : Palettes.Palette;
      First : Natural;
      Exclude_Index : Boolean;
      Excluded_Index : Palette_Index;
      Work : in out Work_Budgets.Meter;
      Object : out Search_Index) return Results.Result;

   type Find_Status is (Find_Ready, Find_Invariant_Failure);
   function Find
     (State : in out Quantization_Storage.Cache_Operations.Cache_State;
      Current_Epoch : Quantization_Storage.Cache_Operations.Epoch;
      Color : Palettes.RGB_Color;
      Search : Search_Index;
      Use_Cache : Boolean;
      Hint_Valid : Boolean;
      Hint_Value : Palette_Index;
      Chosen : out Palette_Index;
      Cache_Hit : out Boolean;
      Work_Used : out Byte_Count) return Find_Status;

   pragma Inline_Always (Node_Count);

private
   type Color_Axis is (Red_Axis, Green_Axis, Blue_Axis);
   subtype Node_Id is Natural range 0 .. 256;
   type Search_Node is record
      Color : Palettes.RGB_Color := (others => 0);
      Minimum : Palettes.RGB_Color := (others => 0);
      Maximum : Palettes.RGB_Color := (others => 0);
      Value : Palette_Index := 0;
      Axis : Color_Axis := Red_Axis;
      Left : Node_Id := 0;
      Right : Node_Id := 0;
   end record;
   type Node_Array is array (Node_Id) of Search_Node;
   type Search_Index is record
      Nodes : Node_Array;
      Colors : Palettes.Color_Array := [others => (others => 0)];
      Root : Node_Id := 0;
      Count : Natural range 0 .. 256 := 0;
   end record;
end Giflib.Internal.Quantization_Mapping;
