with Giflib.Internal.Bytes;
with Giflib.Internal.Diagnostics;
with Giflib.Internal.Extension_Arithmetic;
with Giflib.Internal.Loop_Extensions;
with Giflib.Decoding.Extensions.Retention;
with Giflib.Decoding.Extensions.Transport;
with Giflib.Decoding.Failure_Handling;
with Giflib.Decoding.Session_Transitions;

package body Giflib.Decoding.Extensions is
   use type Metadata.Extension_Kind;

   function Read_Graphic_Control
     (Object : in out Decoder;
      Info : in out Metadata.Extension_Info) return Results.Result
   is separate;

   function Read_Application
     (Object : in out Decoder;
      Info : in out Metadata.Extension_Info) return Results.Result
   is separate;

   function Read_Plain_Text
     (Object : in out Decoder;
      Info : in out Metadata.Extension_Info) return Results.Result
   is separate;

   function Read_Variable_Extension
     (Object : in out Decoder;
      Info : in out Metadata.Extension_Info) return Results.Result
   is separate;

   function Read
     (Object      : in out Decoder;
      Offset      : Source_Offset;
      Label_Value : Byte;
      Info        : out Metadata.Extension_Info) return Results.Result
   is
      Outcome : Results.Result;
   begin
      case Metadata.Kind_Of (Label_Value) is
         when Metadata.Graphic_Control_Extension =>
            Info := (Kind => Metadata.Graphic_Control_Extension,
                     Offset => Offset, Before_Frame => Object.Frames_Seen,
                     others => <>);
         when Metadata.Comment_Extension =>
            Info := (Kind => Metadata.Comment_Extension,
                     Offset => Offset, Before_Frame => Object.Frames_Seen,
                     others => <>);
         when Metadata.Plain_Text_Extension =>
            Info := (Kind => Metadata.Plain_Text_Extension,
                     Offset => Offset, Before_Frame => Object.Frames_Seen,
                     others => <>);
         when Metadata.Application_Extension =>
            Info := (Kind => Metadata.Application_Extension,
                     Offset => Offset, Before_Frame => Object.Frames_Seen,
                     others => <>);
         when Metadata.Unknown_Extension =>
            Info := (Kind => Metadata.Unknown_Extension,
                     Offset => Offset, Before_Frame => Object.Frames_Seen,
                     Label => Label_Value,
                     others => <>);
      end case;

      if Object.Extensions_Seen >= Object.Constraints.Max_Extensions then
         return Results.Failure
           (Errors.Make
              (Errors.Limit_Exceeded,
               (Source_Position => Errors.Source_Position_At (Offset),
                Extension_Label => Errors.Extension_Label_At (Label_Value),
                Expected => Byte_Count (Object.Constraints.Max_Extensions),
                Actual => Byte_Count (Object.Extensions_Seen) + 1,
                Limit => Extension_Count_Limit,
                others => <>)));
      end if;
      Session_Transitions.Record_Extension (Object);

      case Info.Kind is
         when Metadata.Graphic_Control_Extension =>
            Outcome := Read_Graphic_Control (Object, Info);
         when Metadata.Application_Extension =>
            Outcome := Read_Application (Object, Info);
         when Metadata.Plain_Text_Extension =>
            Outcome := Read_Plain_Text (Object, Info);
         when Metadata.Comment_Extension | Metadata.Unknown_Extension =>
            Outcome := Read_Variable_Extension (Object, Info);
      end case;

      if Results.Succeeded (Outcome) then
         Outcome := Retention.Finish (Object, Info);
      end if;
      return Outcome;
   end Read;
end Giflib.Decoding.Extensions;
