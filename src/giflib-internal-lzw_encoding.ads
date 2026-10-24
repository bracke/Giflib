with Giflib.Internal.Ownership;
with Giflib.Results;
with Giflib.Streams;
private with Giflib.Internal.LZW_Arithmetic;
private with Giflib.Internal.Owned_Objects;

package Giflib.Internal.LZW_Encoding is
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

   function Encode
     (Context : in out Workspace;
      Object : in out Streams.Destination'Class;
      Input : Streams.Byte_Array;
      Minimum_Code_Size : Byte;
      Max_Work : Byte_Count;
      Max_Compressed_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count;
      Compressed_Bytes : out Byte_Count;
      Maximum_Index : Byte := 255;
      Interlace_Width : Natural := 0;
      Interlace_Height : Natural := 0) return Results.Result;

   function Encode
     (Context : in out Workspace_Handle;
      Object : in out Streams.Destination'Class;
      Input : Streams.Byte_Array;
      Minimum_Code_Size : Byte;
      Max_Work : Byte_Count;
      Max_Compressed_Bytes : Byte_Count;
      Max_Wire_Bytes : Byte_Count;
      Compressed_Bytes : out Byte_Count;
      Maximum_Index : Byte := 255;
      Interlace_Width : Natural := 0;
      Interlace_Height : Natural := 0) return Results.Result
     with Pre => Is_Allocated (Context);
private
   Hash_Size : constant := LZW_Arithmetic.Hash_Size;
   type Natural_Table is array (Natural range 0 .. Hash_Size - 1) of Natural;
   type Byte_Table is array (Natural range 0 .. Hash_Size - 1) of Byte;
   type Boolean_Table is array (Natural range 0 .. Hash_Size - 1) of Boolean;

   type Workspace is limited record
      Prefix_Key : Natural_Table := [others => 0];
      Suffix_Key : Byte_Table := [others => 0];
      Code_Value : Natural_Table := [others => 0];
      Used : Boolean_Table := [others => False];
   end record;

   package Workspace_Ownership is new Owned_Objects (Workspace);
   type Workspace_Handle is limited record
      Owner : Workspace_Ownership.Handle;
   end record;
end Giflib.Internal.LZW_Encoding;
