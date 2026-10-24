with Giflib.Results;

package Giflib.Internal.Checked_Arithmetic is
   pragma Preelaborate;

   type Count_Result is record
      Outcome : Results.Result := Results.Success;
      Value : Byte_Count := 0;
   end record;

   function Add (Left, Right : Byte_Count) return Count_Result;
   function Multiply (Left, Right : Byte_Count) return Count_Result;
end Giflib.Internal.Checked_Arithmetic;
