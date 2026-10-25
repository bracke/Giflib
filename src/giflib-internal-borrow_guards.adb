package body Giflib.Internal.Borrow_Guards is
   function Is_Active (Object : State) return Boolean is (Object.Active);

   overriding procedure Initialize (Object : in out Guard) is
   begin
      if Object.Object.Active then
         raise Program_Error with "owned storage is already borrowed";
      end if;
      Object.Object.Active := True;
      Object.Acquired := True;
   end Initialize;

   overriding procedure Finalize (Object : in out Guard) is
   begin
      if Object.Acquired then
         Object.Object.Active := False;
         Object.Acquired := False;
      end if;
   end Finalize;
end Giflib.Internal.Borrow_Guards;
