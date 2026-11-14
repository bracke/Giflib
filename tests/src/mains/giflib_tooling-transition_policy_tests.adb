with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Transition_Policy_Index;
with Giflib_Tooling.Transition_Policy_Index.Builders;

package body Giflib_Tooling.Transition_Policy_Tests is
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Indexes renames Giflib_Tooling.Transition_Policy_Index;
   package Builders renames
     Giflib_Tooling.Transition_Policy_Index.Builders;
   use type Builders.Duplicate_Kind;

   procedure Run is
      Policy_Builder : Builders.Builder := Builders.Empty ("session_");
      Isolated : Indexes.Index;
      Policy : Indexes.Index;
      Duplicate : Builders.Duplicate_Kind;
   begin
      Builders.Finish (Builders.Empty, Isolated, Duplicate);
      Check.Check
        (Duplicate = Builders.No_Duplicate,
         "empty transition policy indexes are valid");
      Builders.Add_Global_Call (Policy_Builder, "helpers.advance");
      Builders.Add_Family_Call
        (Policy_Builder, "giflib-decoding", "storage.update");
      Builders.Add_Reviewed_Alias
        (Policy_Builder, "unit.adb", "helpers", "resource_helpers");
      Builders.Finish (Policy_Builder, Policy, Duplicate);
      Check.Check
        (Duplicate = Builders.No_Duplicate
         and then Indexes.Is_Allowed_Call
           (Policy, "helpers.advance", "elsewhere.adb")
         and then Indexes.Is_Allowed_Call
           (Policy, "storage.update", "giflib-decoding-child.adb")
         and then not Indexes.Is_Allowed_Call
           (Policy, "storage.update", "giflib-encoding-child.adb")
         and then Indexes.Is_Allowed_Call
           (Policy, "session_work", "elsewhere.adb")
         and then Indexes.Is_Reviewed_Alias
           (Policy, "unit.adb", "helpers", "resource_helpers"),
         "transition policy indexes accept injected datasets");
      Check.Check
        (not Indexes.Is_Global_Allowed_Call (Isolated, "helpers.advance"),
         "transition policy indexes keep datasets isolated");
      Check.Check
        (Indexes.Allowed_Family
           (Policy, "storage.update", "giflib-decoding-child.adb").Found
         and then not Indexes.Allowed_Family
           (Policy, "storage.update", "giflib-decodingevil.adb").Found,
         "transition policy indexes identify family-scoped approvals");
      Builders.Add_Global_Call (Policy_Builder, "helpers.advance");
      Builders.Finish (Policy_Builder, Policy, Duplicate);
      Check.Check
        (Duplicate = Builders.Duplicate_Global_Call,
         "transition policy indexes diagnose duplicate injected entries");
   end Run;
end Giflib_Tooling.Transition_Policy_Tests;
