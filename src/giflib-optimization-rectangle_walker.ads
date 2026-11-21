with Giflib.Internal.Work_Budgets;

private package Giflib.Optimization.Rectangle_Walker
  with Preelaborate
is
   type Visit_Action is (Continue_Visit, Stop_Visit);

   generic
      with function Visit
        (X : Natural; Y : Natural; Position : Natural) return Visit_Action;
   function Walk
     (Work : in out Internal.Work_Budgets.Meter;
      Left : Natural;
      Top : Natural;
      Width : Natural;
      Height : Natural;
      Canvas_Width : Image_Width)
      return Results.Result;
end Giflib.Optimization.Rectangle_Walker;
