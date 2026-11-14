private package Giflib_Tooling.Source_Limits is
   type Parsing_Limits is record
      Maximum_Source_Length : Natural := 1_000_000;
      Maximum_Tokens : Natural := 250_000;
      Maximum_Structural_Events : Natural := 100_000;
      Maximum_Program_Units : Natural := 50_000;
      Maximum_Model_Storage : Natural := 32 * 1_024 * 1_024;
      Maximum_Structural_Work : Natural := 10_000_000;
      Maximum_Structural_Depth : Natural := 256;
   end record;
   type Discovery_Limits is record
      Maximum_Discovery_Entries : Natural := 50_000;
      Maximum_Source_Files : Natural := 10_000;
      Maximum_Directory_Depth : Natural := 64;
   end record;
   type Cache_Limits is record
      Maximum_Cached_Model_Units : Natural := 128 * 1_024 * 1_024;
      Maximum_Cache_Work : Natural := 128 * 1_024 * 1_024;
   end record;
   type Validation_Limits is record
      Maximum_Validation_Work : Natural := 512 * 1_024 * 1_024;
      Maximum_Validation_Storage_Units : Natural := 128 * 1_024 * 1_024;
   end record;
   type Snapshot_Limits is record
      Maximum_Storage_Units : Natural := 128 * 1_024 * 1_024;
      Maximum_Files : Natural := 20_100;
   end record;
   type Analysis_Limits is record
      Parsing : Parsing_Limits := (others => <>);
      Discovery : Discovery_Limits := (others => <>);
      Cache : Cache_Limits := (others => <>);
      Validation : Validation_Limits := (others => <>);
      Snapshot : Snapshot_Limits := (others => <>);
   end record;
   Default_Parsing_Limits : constant Parsing_Limits := (others => <>);
   Default_Analysis_Limits : constant Analysis_Limits := (others => <>);
end Giflib_Tooling.Source_Limits;
