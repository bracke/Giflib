private package Giflib_Tooling.Configuration_Quotes is
   function Run_Length
     (Value : String; Position : Integer; Delimiter : Character)
      return Natural;

   function Triple_At (Value : String; Position : Integer) return Boolean;
   function Triple_At
     (Value : String; Position : Integer; Delimiter : Character)
      return Boolean;
end Giflib_Tooling.Configuration_Quotes;
