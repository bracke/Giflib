with Giflib.Internal.Blocks;
with Giflib.Internal.Ownership;
with Giflib.Results;
with Giflib.Streams;
private with Giflib.Internal.LZW_Arithmetic;
private with Giflib.Internal.Owned_Objects;

package Giflib.Internal.LZW is
   pragma Preelaborate;

   type Workspace is limited private;
   type Workspace_Handle is limited private;

   function Ensure
     (Object : in out Workspace_Handle;
      Budget : aliased in out Ownership.Byte_Budget;
      Fault : in out Ownership.Fault_State;
      Maximum : Byte_Count) return Ownership.Allocation_Outcome;
   function Release
     (Object : in out Workspace_Handle;
      Budget : aliased in out Ownership.Byte_Budget) return Boolean;
   function Is_Allocated (Object : Workspace_Handle) return Boolean;
   function Decode
     (Context : in out Workspace;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Minimum_Code_Size : Byte;
      Output : out Streams.Byte_Array;
      Decoded_Count : out Byte_Count;
      Max_Work : Byte_Count;
      Frame : Frame_Ordinal := 0;
      Maximum_Index : Byte := 255;
      Interlace_Width : Natural := 0;
      Interlace_Height : Natural := 0) return Results.Result;

   function Decode
     (Context : in out Workspace_Handle;
      Object : in out Streams.Source'Class;
      Blocks_Reader : in out Blocks.Sub_Block_Reader;
      Minimum_Code_Size : Byte;
      Output : out Streams.Byte_Array;
      Decoded_Count : out Byte_Count;
      Max_Work : Byte_Count;
      Frame : Frame_Ordinal := 0;
      Maximum_Index : Byte := 255;
      Interlace_Width : Natural := 0;
      Interlace_Height : Natural := 0) return Results.Result
     with Pre => Is_Allocated (Context);
private
   type Prefix_Table is array
     (Natural range 0 .. LZW_Arithmetic.Dictionary_Size - 1)
     of Natural range 0 .. LZW_Arithmetic.Dictionary_Size - 1;
   type Suffix_Table is array
     (Natural range 0 .. LZW_Arithmetic.Dictionary_Size - 1) of Byte;

   type Workspace is limited record
      Prefix : Prefix_Table := [others => 0];
      Suffix : Suffix_Table := [others => 0];
      Stack : Suffix_Table := [others => 0];
   end record;

   package Workspace_Ownership is new Owned_Objects (Workspace);
   type Workspace_Handle is limited record
      Owner : Workspace_Ownership.Handle;
   end record;
end Giflib.Internal.LZW;
