with Giflib_API_Consumer;

procedure Giflib_Public_API_Check is
   pragma Assert (Giflib_API_Consumer.Streams_Available);
begin
   null;
end Giflib_Public_API_Check;
