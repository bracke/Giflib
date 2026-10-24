package Giflib.Errors is
   pragma Preelaborate;

   type Error_Code is
     (No_Error,
      Source_Read_Failed,
      Source_Unexpected_End,
      Source_Zero_Progress,
      Destination_Write_Failed,
      Destination_Zero_Progress,
      Invalid_Signature,
      Invalid_Version,
      Truncated_Block,
      Invalid_Block,
      Invalid_Dimensions,
      Missing_Color_Table,
      Palette_Index_Out_Of_Range,
      Frame_Out_Of_Bounds,
      LZW_Invalid_Minimum_Code_Size,
      LZW_Invalid_Code,
      LZW_Missing_End_Code,
      LZW_Output_Size_Mismatch,
      Duplicate_Graphic_Control,
      Invalid_Extension,
      Reserved_Disposal_Method,
      Trailing_Data,
      Unsupported_Feature,
      Invalid_State,
      Integer_Overflow,
      Limit_Exceeded,
      Operation_Cancelled,
      Internal_Invariant_Failed);

   type Warning_Code is
     (Generic_Warning,
      Compatibility_Issue,
      Recovery_Applied,
      Reserved_Value_Accepted,
      Trailing_Data_Ignored,
      Warnings_Suppressed);

   type Warning_Severity is (Informational, Compatibility, Recovery, Data_Loss);

   type Diagnostic_Context is record
      Has_Source : Boolean := False;
      Source : Source_Offset := 0;
      Has_Destination : Boolean := False;
      Destination : Destination_Offset := 0;
      Block : Block_Kind := No_Block;
      Extension_Label : Byte := 0;
      Has_Frame : Boolean := False;
      Frame : Frame_Ordinal := 0;
      LZW_Code_Value : LZW_Code := 0;
      LZW_Width : LZW_Code_Width := LZW_Code_Width'First;
      LZW_Code_Ordinal : Byte_Count := 0;
      Has_LZW_Context : Boolean := False;
      Expected : Byte_Count := 0;
      Actual : Byte_Count := 0;
      Limit : Limit_Kind := No_Limit;
      Underlying_Code : Long_Long_Integer := 0;
      Has_Underlying_Code : Boolean := False;
   end record;

   type Error is record
      Code : Error_Code := No_Error;
      Context : Diagnostic_Context;
   end record;

   type Warning is record
      Code : Warning_Code := Generic_Warning;
      Severity : Warning_Severity := Informational;
      Context : Diagnostic_Context;
   end record;

   function Identifier_For (Code : Error_Code) return String;
   function Identifier_For (Code : Warning_Code) return String;
   function Identifier (Item : Error) return String is
     (Identifier_For (Item.Code));
   function Identifier (Item : Warning) return String is
     (Identifier_For (Item.Code));
   function Make
     (Code : Error_Code;
      Context : Diagnostic_Context := (others => <>)) return Error
     with Post => Make'Result.Code = Code;
   function Make_Warning
     (Code : Warning_Code;
      Severity : Warning_Severity;
      Context : Diagnostic_Context := (others => <>)) return Warning;
   function Is_Fatal (Item : Error) return Boolean is (Item.Code /= No_Error);
end Giflib.Errors;
