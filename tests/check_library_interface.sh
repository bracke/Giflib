#!/bin/sh
set -eu

root=${1:-..}
actual_interface=$(mktemp)
expected_interface=$(mktemp)
actual_dependencies=$(mktemp)
expected_dependencies=$(mktemp)
dependency_probe=$(mktemp)
dependency_probe_output=$(mktemp)
trap 'rm -f "$actual_interface" "$expected_interface" "$actual_dependencies" "$expected_dependencies" "$dependency_probe" "$dependency_probe_output"' EXIT HUP INT TERM

transition_fields() {
    spec=$1
    awk '
      /Transition-owned fields begin/ { inside = 1; next }
      /Transition-owned fields end/ { inside = 0 }
      inside && /^[[:space:]]*[[:alpha:]][[:alnum:]_]*[[:space:]]*:/ {
        field = $0
        sub(/^[[:space:]]*/, "", field)
        sub(/[[:space:]]*:.*/, "", field)
        fields = fields (fields == "" ? "" : "|") field
      }
      END { print fields }
    ' "$root/src/$spec"
}

check_transition_writes() {
    prefix=$1
    allowed=$2
    spec=$3
    fields=$(transition_fields "$spec")
    if [ -z "$fields" ]; then
        echo "$prefix transition field manifest is empty" >&2
        exit 1
    fi
    violations=$(find "$root/src" -type f -name "giflib-$prefix*.adb" \
      ! -name "$allowed" -print | while IFS= read -r source_file; do
        awk -v file="$source_file" -v fields="$fields" '
          {
            sub(/--.*/, "")
            statement = statement " " $0
            while (index(statement, ";") != 0) {
              stop = index(statement, ";")
              clause = substr(statement, 1, stop - 1)
              statement = substr(statement, stop + 1)
              gsub(/[[:space:]]+/, " ", clause)
              pattern = "[[:alnum:]_]+[.](" fields ")" \
                        "([[:space:]]*[(][^)]*[)])?[[:space:]]*:="
              if (clause ~ pattern) print file ":" clause ";"
              rename_pattern = "renames[[:space:]]+[[:alnum:]_]+[.](" \
                               fields ")([^[:alnum:]_]|$)"
              if (clause ~ rename_pattern) print file ":" clause ";"
            }
          }
        ' "$source_file"
      done)
    if [ -n "$violations" ]; then
        echo "$prefix session fields are written outside their transition owner" >&2
        echo "$violations" >&2
        exit 1
    fi
}

check_transition_calls() {
    prefix=$1
    allowed=$2
    operations=$3
    violations=$(find "$root/src" -type f -name "giflib-$prefix*.adb" \
      ! -name "$allowed" -print | while IFS= read -r source_file; do
        awk -v file="$source_file" -v operations="$operations" '
          {
            sub(/--.*/, "")
            statement = statement " " $0
            while (index(statement, ";") != 0) {
              stop = index(statement, ";")
              clause = substr(statement, 1, stop - 1)
              statement = substr(statement, stop + 1)
              gsub(/[[:space:]]+/, " ", clause)
              pattern = "State_Arithmetic[.](" operations ")" \
                        "[[:space:]]*[(]"
              if (clause ~ pattern) print file ":" clause ";"
            }
          }
        ' "$source_file"
      done)
    if [ -n "$violations" ]; then
        echo "$prefix state arithmetic is mutated outside its transition owner" >&2
        echo "$violations" >&2
        exit 1
    fi
}

check_transition_writes \
  decoding \
  giflib-decoding-session_transitions.adb \
  giflib-decoding.ads
check_transition_writes \
  encoding \
  giflib-encoding-session_transitions.adb \
  giflib-encoding.ads
check_transition_calls \
  decoding \
  giflib-decoding-session_transitions.adb \
  'Reset|Fail|Initialize|Header_Read|Frame_Discovered|Await_Frame_Decision|Begin_Frame|Complete_Frame|Complete_Stream|Cancel|Finalize'
check_transition_calls \
  encoding \
  giflib-encoding-session_transitions.adb \
  'Fail|Initialize|Define_Screen|Frame_Accepted|Record_Extension|Accept_Data|Complete|Cancel|Finalize'

extract_internal_dependencies() {
    source_file=$1
    display_name=$2
    awk -v file="$display_name" '
      {
        sub(/--.*/, "")
        statement = statement " " $0
        while (index(statement, ";") != 0) {
          stop = index(statement, ";")
          clause = substr(statement, 1, stop - 1)
          statement = substr(statement, stop + 1)
          gsub(/[[:space:]]+/, " ", clause)
          sub(/^ /, "", clause)
          sub(/ $/, "", clause)
          if (clause ~ /^((limited|private) )*with / &&
              clause ~ /Giflib[.]Internal([^[:alnum:]_]|$)/) {
            print file ":" clause ";"
          }
        }
      }
    ' "$source_file"
}

cat >"$dependency_probe" <<'EOF'
with Giflib.Internal;
private with Giflib.Internal.Ownership;
EOF
extract_internal_dependencies "$dependency_probe" probe.ads >"$dependency_probe_output"
if [ "$(wc -l <"$dependency_probe_output")" -ne 2 ]; then
    echo "internal dependency scanner missed a parent or child unit" >&2
    exit 1
fi

awk '
  /for[[:space:]]+Library_Interface[[:space:]]+use/ { inside = 1 }
  inside {
    sub(/--.*/, "")
    rest = $0
    while (match(rest, /"[^"]+"/)) {
      print substr(rest, RSTART + 1, RLENGTH - 2)
      rest = substr(rest, RSTART + RLENGTH)
    }
  }
  inside && /\);/ { exit }
' "$root/giflib.gpr" >"$actual_interface"

sed -n '/^Giflib$/,/^Giflib.Internal.Work_Budgets$/p' <<'EOF' >"$expected_interface"
Giflib
Giflib.Animations
Giflib.Capabilities
Giflib.Decoding
Giflib.Encoding
Giflib.Errors
Giflib.Frames
Giflib.Images
Giflib.Limits
Giflib.Metadata
Giflib.Optimization
Giflib.Palettes
Giflib.Quantization
Giflib.Results
Giflib.Streams
Giflib.Version
Giflib.Internal
Giflib.Internal.Blocks
Giflib.Internal.Borrow_Guards
Giflib.Internal.Budget_Arithmetic
Giflib.Internal.Cleanup
Giflib.Internal.Decoder_Storage
Giflib.Internal.Encoder_Storage
Giflib.Internal.Interlacing
Giflib.Internal.LZW
Giflib.Internal.LZW_Arithmetic
Giflib.Internal.LZW_Decoder_Dictionary
Giflib.Internal.LZW_Encoding
Giflib.Internal.LZW_Encoder_Dictionary
Giflib.Internal.Metadata_Store
Giflib.Internal.Owned_Arrays
Giflib.Internal.Owned_Buffers
Giflib.Internal.Owned_Element_Vectors
Giflib.Internal.Owned_Objects
Giflib.Internal.Owned_Vectors
Giflib.Internal.Ownership
Giflib.Internal.Ownership_Arithmetic
Giflib.Internal.Quantization_Buffer_Arithmetic
Giflib.Internal.Quantization_Dithering
Giflib.Internal.Quantization_Palette
Giflib.Internal.Quantization_Storage
Giflib.Internal.Work_Budgets
EOF

if ! cmp -s "$expected_interface" "$actual_interface"; then
    echo "library interface does not match the reviewed semantic-closure manifest" >&2
    diff -u "$expected_interface" "$actual_interface" >&2 || true
    exit 1
fi

: >"$actual_dependencies"
while IFS= read -r unit; do
    case "$unit" in
        Giflib.Internal*) break ;;
    esac
    spec=$(printf '%s\n' "$unit" | awk '{ name = tolower($0); gsub(/\./, "-", name); print name ".ads" }')
    if [ ! -f "$root/src/$spec" ]; then
        echo "library interface source is missing: $spec" >&2
        exit 1
    fi
    extract_internal_dependencies "$root/src/$spec" "$spec" >>"$actual_dependencies"
done <"$actual_interface"

sed -n '/^giflib-decoding.ads:/,/^giflib-quantization.ads:private with Giflib.Internal.Quantization_Storage;$/p' <<'EOF' >"$expected_dependencies"
giflib-decoding.ads:private with Giflib.Internal.Decoder_Storage;
giflib-decoding.ads:private with Giflib.Internal.Ownership;
giflib-encoding.ads:private with Giflib.Internal.Encoder_Storage;
giflib-encoding.ads:private with Giflib.Internal.Ownership;
giflib-quantization.ads:private with Giflib.Internal.Ownership;
giflib-quantization.ads:private with Giflib.Internal.Quantization_Storage;
EOF

if ! cmp -s "$expected_dependencies" "$actual_dependencies"; then
    echo "public specifications have unreviewed internal dependencies" >&2
    diff -u "$expected_dependencies" "$actual_dependencies" >&2 || true
    exit 1
fi
