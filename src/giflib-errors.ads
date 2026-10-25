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
      Invalid_Index,
      Buffer_Size_Mismatch,
      Output_Variant_Mismatch,
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

   type Position_State is
     (Position_Not_Checked, Position_Unavailable, Position_Available);

   type Source_Position_Context
     (State : Position_State := Position_Not_Checked)
   is record
      case State is
         when Position_Available =>
            Value : Source_Offset := 0;
         when Position_Not_Checked | Position_Unavailable =>
            null;
      end case;
   end record;

   type Destination_Position_Context
     (State : Position_State := Position_Not_Checked)
   is record
      case State is
         when Position_Available =>
            Value : Destination_Offset := 0;
         when Position_Not_Checked | Position_Unavailable =>
            null;
      end case;
   end record;

   function Source_Position_At
     (Value : Source_Offset) return Source_Position_Context is
     ((State => Position_Available, Value => Value));
   function Destination_Position_At
     (Value : Destination_Offset) return Destination_Position_Context is
     ((State => Position_Available, Value => Value));

   type Frame_Context (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Frame_Ordinal := 0;
         when False =>
            null;
      end case;
   end record;

   function Frame_At (Value : Frame_Ordinal) return Frame_Context is
     ((Present => True, Value => Value));

   type LZW_Context (Present : Boolean := False) is record
      case Present is
         when True =>
            Code_Value : LZW_Code := 0;
            Width : LZW_Code_Width := LZW_Code_Width'First;
            Code_Ordinal : Byte_Count := 0;
         when False =>
            null;
      end case;
   end record;

   function LZW_At
     (Code_Value : LZW_Code;
      Width : LZW_Code_Width;
      Code_Ordinal : Byte_Count) return LZW_Context is
     ((Present => True,
       Code_Value => Code_Value,
       Width => Width,
       Code_Ordinal => Code_Ordinal));

   type Underlying_Code_Context (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Long_Long_Integer := 0;
         when False =>
            null;
      end case;
   end record;

   function Underlying_Code_At
     (Value : Long_Long_Integer) return Underlying_Code_Context is
     ((Present => True, Value => Value));

   type Extension_Label_Context (Present : Boolean := False) is record
      case Present is
         when True =>
            Value : Byte := 0;
         when False =>
            null;
      end case;
   end record;

   function Extension_Label_At
     (Value : Byte) return Extension_Label_Context is
     ((Present => True, Value => Value));

   type Diagnostic_Context is record
      Source_Position : Source_Position_Context;
      Destination_Position : Destination_Position_Context;
      Block : Block_Kind := No_Block;
      Extension_Label : Extension_Label_Context;
      Frame : Frame_Context;
      LZW : LZW_Context;
      Expected : Byte_Count := 0;
      Actual : Byte_Count := 0;
      Limit : Limit_Kind := No_Limit;
      Underlying_Code : Underlying_Code_Context;
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
