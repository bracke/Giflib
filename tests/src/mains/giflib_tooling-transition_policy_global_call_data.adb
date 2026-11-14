with Ada.Strings.Unbounded;

package body Giflib_Tooling.Transition_Policy_Global_Call_Data is
   use Ada.Strings.Unbounded;
   type Name_Array is array (Positive range <>) of Unbounded_String;
   Session_Prefix_Value : constant String := "session_transitions.";
   Allowed_Calls : constant Name_Array :=
     [To_Unbounded_String ("state_arithmetic.can_initialize"),
      To_Unbounded_String ("state_arithmetic.can_cancel"),
      To_Unbounded_String ("state_arithmetic.can_configure"),
      To_Unbounded_String ("state_arithmetic.can_define_screen"),
      To_Unbounded_String ("state_arithmetic.can_read_event"),
      To_Unbounded_String ("state_arithmetic.can_read_header"),
      To_Unbounded_String ("state_arithmetic.can_process_frame"),
      To_Unbounded_String ("state_arithmetic.can_accept_data"),
      To_Unbounded_String ("state_arithmetic.can_finish"),
      To_Unbounded_String ("arithmetic.appended_length"),
      To_Unbounded_String ("session_arithmetic.has_natural_capacity"),
      To_Unbounded_String ("geometry_arithmetic.analyze_rectangle"),
      To_Unbounded_String ("internal.budget_arithmetic.charge"),
      To_Unbounded_String ("errors.frame_at"),
      To_Unbounded_String ("errors.make"),
      To_Unbounded_String ("internal.diagnostics.at_destination"),
      To_Unbounded_String ("internal.diagnostics.at_source"),
      To_Unbounded_String ("internal.geometry_arithmetic.area"),
      To_Unbounded_String ("internal.resource_diagnostics.allocation_result"),
      To_Unbounded_String ("palettes.contains"),
      To_Unbounded_String ("palettes.same_entries"),
      To_Unbounded_String ("animations.raw_count"),
      To_Unbounded_String ("results.failure")];

   function Session_Prefix return String is (Session_Prefix_Value);
   procedure Visit
     (Process : not null access procedure (Callee : String)) is
   begin
      for Item of Allowed_Calls loop
         Process (To_String (Item));
      end loop;
   end Visit;
end Giflib_Tooling.Transition_Policy_Global_Call_Data;
