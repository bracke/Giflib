with Giflib.Errors;

package Giflib.Results is
   pragma Preelaborate;

   type Status is (Ok, Failed);

   type Result is record
      First_Error : Errors.Error := Errors.No_Error_Value;
   end record;

   function Success return Result is
     ((First_Error => Errors.No_Error_Value));
   function Failure (Code : Errors.Error_Code) return Result is
     ((First_Error => Errors.Make (Code)));
   function Failure (Item : Errors.Error) return Result is
     ((First_Error => Item));
   function Status_Of (Item : Result) return Status is
     (if Errors.Is_Fatal (Item.First_Error) then Failed else Ok);
   function Succeeded (Item : Result) return Boolean is
     (not Errors.Is_Fatal (Item.First_Error));
end Giflib.Results;
