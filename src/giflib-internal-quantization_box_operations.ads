with Giflib.Palettes;
with Giflib.Internal.Quantization_Histograms;
with Giflib.Internal.Work_Budgets;

package Giflib.Internal.Quantization_Box_Operations is
   pragma Preelaborate;

   package Histogram_Data renames Giflib.Internal.Quantization_Histograms;

   type Color_Box is record
      R_Min : Natural range 0 .. 31;
      R_Max : Natural range 0 .. 31;
      G_Min : Natural range 0 .. 31;
      G_Max : Natural range 0 .. 31;
      B_Min : Natural range 0 .. 31;
      B_Max : Natural range 0 .. 31;
      Population : Natural;
      First : Histogram_Data.Occupied_Position;
      Last : Histogram_Data.Occupied_Position;
   end record;

   type Box_Array is array (Natural range 0 .. 255) of Color_Box;

   type Box_Result_Kind is (Box_Empty, Box_Ready, Box_Work_Limit);
   type Box_Result (Kind : Box_Result_Kind := Box_Empty) is record
      case Kind is
         when Box_Ready =>
            Value : Color_Box;
         when Box_Empty | Box_Work_Limit =>
            null;
      end case;
   end record;

   type Split_Result_Kind is
     (Split_Unavailable, Split_Ready, Split_Work_Limit);
   type Split_Result (Kind : Split_Result_Kind := Split_Unavailable) is record
      case Kind is
         when Split_Ready =>
            Left : Color_Box;
            Right : Color_Box;
         when Split_Unavailable | Split_Work_Limit =>
            null;
      end case;
   end record;

   function Analyze
     (Histogram : Histogram_Data.Histogram_State;
      First : Histogram_Data.Occupied_Position;
      Last : Histogram_Data.Occupied_Position;
      Work : in out Work_Budgets.Meter) return Box_Result;

   function Spread (Item : Color_Box) return Natural;

   function Split
     (Histogram : in out Histogram_Data.Histogram_State;
      Item : Color_Box;
      Work : in out Work_Budgets.Meter) return Split_Result;

   type Representative_Result_Kind is
     (Representative_Empty, Representative_Ready, Representative_Work_Limit);
   type Representative_Result
     (Kind : Representative_Result_Kind := Representative_Work_Limit) is record
      case Kind is
         when Representative_Ready =>
            Value : Palettes.RGB_Color;
         when Representative_Empty | Representative_Work_Limit =>
            null;
      end case;
   end record;

   function Representative
     (Histogram : Histogram_Data.Histogram_State;
      Item : Color_Box;
      Work : in out Work_Budgets.Meter) return Representative_Result;
end Giflib.Internal.Quantization_Box_Operations;
