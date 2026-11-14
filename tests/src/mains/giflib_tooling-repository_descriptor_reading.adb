with Giflib_Tooling.Repository_Diagnostics;

package body Giflib_Tooling.Repository_Descriptor_Reading is
   package Handles renames Giflib_Tooling.Repository_Handles;
   package Diagnostics renames Giflib_Tooling.Repository_Diagnostics;

   function Read_Bounded
     (File : Handles.Owner;
      Maximum_Length : Natural;
      After_First_Read : access procedure := null;
      Before_Allocate : access procedure (Length : Natural) := null)
      return String
   is
      procedure Read_Exact (Buffer : out String) is
         Offset : Natural := 0;
      begin
         while Offset < Buffer'Length loop
            declare
               Read_Count : constant Integer := Handles.Read
                 (File, Buffer (Buffer'First + Offset)'Address,
                  Buffer'Length - Offset);
            begin
               if Read_Count <= 0 then
                  Diagnostics.Raise_Input
                    (Diagnostics.File_Changed_While_Reading);
               end if;
               Offset := Offset + Read_Count;
            end;
         end loop;
      end Read_Exact;

      procedure Require_End_Of_File is
         Extra : aliased Character;
      begin
         if Handles.Read (File, Extra'Address, 1) /= 0 then
            Diagnostics.Raise_Input
              (Diagnostics.File_Changed_While_Reading);
         end if;
      end Require_End_Of_File;

      Length : Long_Integer;
   begin
      if not Handles.Is_Open (File) then
         Diagnostics.Raise_Input (Diagnostics.Input_Open_Failed);
      end if;
      Length := Handles.Length (File);
      if Length < 0 or else Length > Long_Integer (Maximum_Length) then
         Diagnostics.Raise_Input (Diagnostics.File_Length_Limit_Exceeded);
      end if;
      if Before_Allocate /= null then
         Before_Allocate (Natural (Length));
      end if;
      Handles.Seek_Start (File);
      return Result : String (1 .. Natural (Length)) do
         Read_Exact (Result);
         Require_End_Of_File;
         if After_First_Read /= null then
            After_First_Read.all;
         end if;
         Handles.Seek_Start (File);
         if Handles.Length (File) /= Length then
            Diagnostics.Raise_Input
              (Diagnostics.File_Changed_While_Reading);
         end if;
         declare
            Verification : aliased String (1 .. 8_192);
            Offset : Natural := 0;
         begin
            while Offset < Result'Length loop
               declare
                  Needed : constant Natural :=
                    Natural'Min
                      (Verification'Length, Result'Length - Offset);
               begin
                  Read_Exact (Verification (1 .. Needed));
                  if Verification (1 .. Needed) /=
                    Result
                      (Result'First + Offset
                       .. Result'First + Offset + Needed - 1)
                  then
                     Diagnostics.Raise_Input
                       (Diagnostics.File_Changed_While_Reading);
                  end if;
                  Offset := Offset + Needed;
               end;
            end loop;
         end;
         Require_End_Of_File;
         Handles.Seek_Start (File);
      end return;
   end Read_Bounded;
end Giflib_Tooling.Repository_Descriptor_Reading;
