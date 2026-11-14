with Ada.Strings.Unbounded;

with Giflib_Tooling.Repository_Analysis;
with Giflib_Tooling.Self_Test_Support;
with Giflib_Tooling.Name_Collections;
with Giflib_Tooling.Source_Model;
with Giflib_Tooling.Work_Budgets;

package body Giflib_Tooling.Repository_Analysis_Tests is
   package Analysis renames Giflib_Tooling.Repository_Analysis;
   package Check renames Giflib_Tooling.Self_Test_Support;
   package Source renames Giflib_Tooling.Source_Model;

   procedure Run is
      Budget : Giflib_Tooling.Work_Budgets.Budget;
      Inventory : constant Giflib_Tooling.Name_Collections.Name_Vectors.Vector :=
        Analysis.Documented_Executables
          ("```markdown" & ASCII.LF &
           "### Ada tooling inventory" & ASCII.LF &
           "- `decoy`" & ASCII.LF & "```not-a-close" & ASCII.LF &
           "### Ada tooling inventory" & ASCII.LF &
           "- `still_decoy`" & ASCII.LF & "```" & ASCII.LF &
           "    ### Ada tooling inventory" & ASCII.LF &
           "    - `indented_decoy`" & ASCII.LF &
           "<!--" & ASCII.LF &
           "### Ada tooling inventory" & ASCII.LF &
           "- `commented_decoy`" & ASCII.LF & "-->" & ASCII.LF &
           "### Ada tooling inventory" & ASCII.CR & ASCII.LF &
           "- `giflib_check`" & ASCII.CR & ASCII.LF);
   begin
      Check.Check
        (Analysis.Declares_Main
           (Source.Parse ("procedure Tool is begin null; end Tool;"), "tool",
            Budget)
         and then Analysis.Declares_Main
           (Source.Parse
              ("procedure Tool with Pre => True is begin null; end Tool;"),
            "tool", Budget),
         "parameterless library-level procedures may carry aspects");
      Check.Check
        (not Analysis.Declares_Main
           (Source.Parse
              ("procedure Tool (Value : Natural) is begin null; end Tool;"),
            "tool", Budget)
         and then not Analysis.Declares_Main
           (Source.Parse
              ("generic procedure Tool is begin null; end Tool;"), "tool",
            Budget)
         and then not Analysis.Declares_Main
           (Source.Parse
              ("generic type Item is private; procedure Tool is begin null; " &
               "end Tool;"), "tool", Budget)
         and then not Analysis.Declares_Main
           (Source.Parse
              ("generic with procedure Visit; procedure Tool is begin null; " &
               "end Tool;"), "tool", Budget),
         "parameterized and generic procedures are not executable mains");
      Check.Check
        (Natural (Inventory.Length) = 1
         and then Ada.Strings.Unbounded.To_String
           (Inventory.First_Element) = "giflib_check",
         "executable inventory parsing ignores hidden Markdown content");
   end Run;
end Giflib_Tooling.Repository_Analysis_Tests;
