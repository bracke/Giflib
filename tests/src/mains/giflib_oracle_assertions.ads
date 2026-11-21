with Giflib.Streams;

package Giflib_Oracle_Assertions is
   procedure Require (Condition : Boolean; Message : String);
   procedure Exact_RGBA
     (Path : String;
      Expected : Giflib.Streams.Byte_Array;
      Description : String);
end Giflib_Oracle_Assertions;
