private package Giflib_Tooling.Configuration_Logical_Lines is
   procedure Scan
     (Text : String;
      Process : not null access procedure
        (Line : String; Stop : in out Boolean);
      Incomplete : out Boolean);
end Giflib_Tooling.Configuration_Logical_Lines;
