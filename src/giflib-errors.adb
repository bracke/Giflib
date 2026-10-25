package body Giflib.Errors is
   function Identifier_For (Code : Error_Code) return String is
   begin
      case Code is
         when No_Error                      => return "gif.ok";
         when Source_Read_Failed            => return "gif.source.read_failed";
         when Source_Unexpected_End         => return "gif.source.unexpected_end";
         when Source_Zero_Progress          => return "gif.stream.zero_progress";
         when Destination_Write_Failed      => return "gif.destination.write_failed";
         when Destination_Zero_Progress     => return "gif.stream.destination_zero_progress";
         when Invalid_Signature             => return "gif.invalid_signature";
         when Invalid_Version               => return "gif.invalid_version";
         when Truncated_Block               => return "gif.truncated_block";
         when Invalid_Block                 => return "gif.invalid_block";
         when Invalid_Dimensions            => return "gif.dimensions.invalid";
         when Missing_Color_Table           => return "gif.palette.missing";
         when Palette_Index_Out_Of_Range    => return "gif.palette.index_out_of_range";
         when Frame_Out_Of_Bounds           => return "gif.frame.out_of_bounds";
         when LZW_Invalid_Minimum_Code_Size => return "gif.lzw.invalid_minimum_code_size";
         when LZW_Invalid_Code              => return "gif.lzw.invalid_code";
         when LZW_Missing_End_Code          => return "gif.lzw.missing_end_code";
         when LZW_Output_Size_Mismatch      => return "gif.lzw.output_size_mismatch";
         when Duplicate_Graphic_Control     => return "gif.extension.duplicate_graphic_control";
         when Invalid_Extension             => return "gif.extension.invalid";
         when Reserved_Disposal_Method      => return "gif.disposal.reserved";
         when Trailing_Data                 => return "gif.trailing_data";
         when Unsupported_Feature           => return "gif.feature.unsupported";
         when Invalid_Index                 => return "gif.argument.index_out_of_range";
         when Buffer_Size_Mismatch          => return "gif.argument.buffer_size_mismatch";
         when Output_Variant_Mismatch       => return "gif.argument.output_variant_mismatch";
         when Invalid_State                 => return "gif.state.invalid";
         when Integer_Overflow              => return "gif.security.integer_overflow";
         when Limit_Exceeded                => return "gif.limit.exceeded";
         when Operation_Cancelled           => return "gif.operation.cancelled";
         when Internal_Invariant_Failed     => return "gif.internal.invariant_failed";
      end case;
   end Identifier_For;

   function Identifier_For (Code : Warning_Code) return String is
   begin
      case Code is
         when Generic_Warning          => return "gif.warning";
         when Compatibility_Issue      => return "gif.warning.compatibility";
         when Recovery_Applied         => return "gif.warning.recovery";
         when Reserved_Value_Accepted  => return "gif.warning.reserved_value";
         when Trailing_Data_Ignored    => return "gif.warning.trailing_data";
         when Warnings_Suppressed      => return "gif.warning.suppressed";
      end case;
   end Identifier_For;

   function Make (Code : Error_Code; Context : Diagnostic_Context := (others => <>)) return Error is
   begin
      return
        (Code => Code,
         Context => Context);
   end Make;

   function Make_Warning
     (Code : Warning_Code;
      Severity : Warning_Severity;
      Context : Diagnostic_Context := (others => <>)) return Warning
   is
   begin
      return
        (Code => Code,
         Severity => Severity,
         Context => Context);
   end Make_Warning;
end Giflib.Errors;
