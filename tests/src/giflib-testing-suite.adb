with AUnit.Test_Cases;
with Giflib.Testing.Test_Allocation_Failures;
with Giflib.Testing.Test_Blocks;
with Giflib.Testing.Test_Container;
with Giflib.Testing.Test_Compositing;
with Giflib.Testing.Test_Descriptors;
with Giflib.Testing.Test_Decoder;
with Giflib.Testing.Test_LZW;
with Giflib.Testing.Test_LZW_Encoding;
with Giflib.Testing.Test_Optimization;
with Giflib.Testing.Test_Policy;
with Giflib.Testing.Test_Quantization;
with Giflib.Testing.Test_Image_Data;
with Giflib.Testing.Test_Interlacing;
with Giflib.Testing.Test_Foundation;
with Giflib.Testing.Test_Extensions;
with Giflib.Testing.Test_Encoding;
with Giflib.Testing.Test_Streams;

package body Giflib.Testing.Suite is
   function All_Tests return AUnit.Test_Suites.Access_Test_Suite is
      Suite : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
      Allocation_Failures : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_Allocation_Failures.Test;
      Blocks : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_Blocks.Test;
      Container : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_Container.Test;
      Compositing : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_Compositing.Test;
      Descriptors : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_Descriptors.Test;
      Decoder : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_Decoder.Test;
      LZW : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_LZW.Test;
      LZW_Encoding : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_LZW_Encoding.Test;
      Optimization : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_Optimization.Test;
      Policy : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_Policy.Test;
      Quantization : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_Quantization.Test;
      Image_Data : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_Image_Data.Test;
      Interlacing : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_Interlacing.Test;
      Foundation : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_Foundation.Test;
      Extensions : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_Extensions.Test;
      Encoding : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_Encoding.Test;
      Streams : constant AUnit.Test_Cases.Test_Case_Access :=
        new Giflib.Testing.Test_Streams.Test;
   begin
      Suite.Add_Test (Allocation_Failures);
      Suite.Add_Test (Blocks);
      Suite.Add_Test (Container);
      Suite.Add_Test (Compositing);
      Suite.Add_Test (Descriptors);
      Suite.Add_Test (Decoder);
      Suite.Add_Test (LZW);
      Suite.Add_Test (LZW_Encoding);
      Suite.Add_Test (Optimization);
      Suite.Add_Test (Policy);
      Suite.Add_Test (Quantization);
      Suite.Add_Test (Image_Data);
      Suite.Add_Test (Interlacing);
      Suite.Add_Test (Foundation);
      Suite.Add_Test (Extensions);
      Suite.Add_Test (Encoding);
      Suite.Add_Test (Streams);
      return Suite;
   end All_Tests;
end Giflib.Testing.Suite;
