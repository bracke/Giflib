#!/bin/sh
set -eu

root=${1:-..}
probe_dir=$(mktemp -d)
trap 'rm -rf "$probe_dir"' EXIT HUP INT TERM

session_fields() {
    spec=$1
    record_type=$2
    excluded=$3
    awk -v record_type="$record_type" -v excluded="$excluded" '
      BEGIN {
        count = split(excluded, names, "|")
        for (item = 1; item <= count; item++) omit[names[item]] = 1
      }
      $0 ~ "^[[:space:]]*type[[:space:]]+" record_type \
             "([^[:alnum:]_]|$)" { found = 1 }
      found && /is[[:space:]]+limited[[:space:]]+record/ {
        inside = 1
        next
      }
      inside && /^[[:space:]]*end[[:space:]]+record[[:space:]]*;/ { exit }
      inside {
        line = $0
        sub(/--.*/, "", line)
        declaration = declaration " " line
        if (index(declaration, ";") != 0) {
          declaration_names = declaration
          sub(/:.*/, "", declaration_names)
          if (declaration_names ~ /^[[:space:]]*[[:alpha:]][[:alnum:]_]*([[:space:]]*,[[:space:]]*[[:alpha:]][[:alnum:]_]*)*[[:space:]]*$/) {
            count = split(declaration_names, declared, ",")
            for (item = 1; item <= count; item++) {
              field = declared[item]
              gsub(/[[:space:]]/, "", field)
              if (!(field in omit)) {
                fields = fields (fields == "" ? "" : "|") field
              }
            }
          }
          declaration = ""
        }
      }
      END { print fields }
    ' "$spec"
}

state_mutators() {
    spec=$1
    awk '
      {
        sub(/--.*/, "")
        statement = statement " " $0
        while (index(statement, ";") != 0) {
          stop = index(statement, ";")
          clause = substr(statement, 1, stop - 1)
          statement = substr(statement, stop + 1)
          gsub(/[[:space:]]+/, " ", clause)
          if (clause ~ /(^| )procedure[[:space:]]+[[:alpha:]][[:alnum:]_]*/) {
            sub(/^.*procedure[[:space:]]+/, "", clause)
            name = clause
            sub(/[^[:alnum:]_].*$/, "", name)
            if (!seen[name]++) operations = operations \
              (operations == "" ? "" : "|") name
          }
        }
      }
      END { print operations }
    ' "$spec"
}

scan_transition_file() {
    source_file=$1
    fields=$2
    operations=$3
    awk -v file="$source_file" -v fields="$fields" -v operations="$operations" '
      {
        sub(/--.*/, "")
        statement = statement " " $0
        while (index(statement, ";") != 0) {
          stop = index(statement, ";")
          clause = substr(statement, 1, stop - 1)
          statement = substr(statement, stop + 1)
          gsub(/[[:space:]]+/, " ", clause)
          write_pattern = "[[:alnum:]_]+[.](" fields ")" \
                          "([.][[:alnum:]_]+|" \
                          "[[:space:]]*[(][^)]*[)])*[[:space:]]*:="
          rename_pattern = "renames[[:space:]]+[[:alnum:]_]+[.](" \
                           fields ")([^[:alnum:]_]|$)"
          call_pattern = "State_Arithmetic[.](" operations ")" \
                         "[[:space:]]*[(]"
          arithmetic_rename = "renames[[:space:]]+" \
                              "([[:alnum:]_]+[.])*State_Arithmetic" \
                              "([^[:alnum:]_]|$)"
          field_argument = "(^|[(,])[[:space:]]*[[:alnum:]_]+[.](" \
                           fields ")([.][[:alnum:]_]+|" \
                           "[[:space:]]*[(][^)]*[)])*" \
                           "[[:space:]]*([,)]|$)"
          mutating_name = "(^|[.[:space:]])(Mutate|Update|Set|Reset|Clear|" \
                          "Assign|Replace|Change)" \
                          "[[:alnum:]_]*[[:space:]]*[(]"
          whole_object = "[(,][[:space:]]*(Object|Encoder|Decoder)" \
                         "[[:space:]]*([,)]|$)"
          call_clause = clause
          sub(/^.* (begin|then|else|loop) /, "", call_clause)
          named_mutation = call_clause ~ mutating_name &&
                           (call_clause ~ field_argument ||
                            call_clause ~ whole_object) &&
                           call_clause !~ /Session_Transitions[.]/ &&
                           call_clause !~ /Resource_Management[.]/
          if (clause ~ write_pattern || clause ~ rename_pattern ||
              clause ~ call_pattern || clause ~ arithmetic_rename ||
              named_mutation) print file ":" clause ";"
        }
      }
    ' "$source_file"
}

check_session() {
    prefix=$1
    record_type=$2
    owner=$3
    fields=$(session_fields "$root/src/giflib-$prefix.ads" "$record_type" \
      'Resources|Quantizer_Data|Cleanup_State|Allocation_Fault')
    operations=$(state_mutators "$root/src/giflib-$prefix-state_arithmetic.ads")
    if [ -z "$fields" ] || [ -z "$operations" ]; then
        echo "$prefix transition manifest is empty" >&2
        exit 1
    fi
    violations=$(find "$root/src" -type f -name "giflib-$prefix*.adb" \
      ! -name "$owner" -print | while IFS= read -r source_file; do
        scan_transition_file "$source_file" "$fields" "$operations"
      done)
    if [ -n "$violations" ]; then
        echo "$prefix session state is mutated outside its transition owner" >&2
        echo "$violations" >&2
        exit 1
    fi
}

cat >"$probe_dir/probe.ads" <<'EOF'
type Probe is limited record
   Current_State,
   Other_State : Integer;
   Resources : Integer;
   Quantizer_Data : Integer;
   New_Field : Integer;
   Allocation_Fault : Integer;
end record;
EOF
cat >"$probe_dir/state.ads" <<'EOF'
procedure Existing (State : in out Integer);
procedure Newly_Added (State : out Integer);
function Observe (State : Integer) return Boolean;
EOF
cat >"$probe_dir/probe.adb" <<'EOF'
Object.New_Field := 1;
Object.Other_State.Component := 1;
State_Arithmetic.Newly_Added (Object.Current_State);
package SA renames State_Arithmetic;
Mutate (Object.Current_State);
Mutate (0, Object.Current_State);
Value := Mutate (Object.Current_State);
Mutate (Object);
EOF
probe_fields=$(session_fields "$probe_dir/probe.ads" Probe \
  'Resources|Quantizer_Data|Cleanup_State|Allocation_Fault')
probe_operations=$(state_mutators "$probe_dir/state.ads")
if [ "$probe_fields" != 'Current_State|Other_State|New_Field' ] ||
   [ "$probe_operations" != 'Existing|Newly_Added' ] ||
   [ "$(scan_transition_file "$probe_dir/probe.adb" "$probe_fields" \
        "$probe_operations" | wc -l)" -ne 8 ]; then
    echo "session transition checker self-test failed" >&2
    exit 1
fi

check_session decoding Decoder giflib-decoding-session_transitions.adb
check_session encoding Encoder giflib-encoding-session_transitions.adb
