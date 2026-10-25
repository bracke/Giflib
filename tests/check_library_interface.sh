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
Giflib.Internal.Budget_Arithmetic
Giflib.Internal.Decoder_Storage
Giflib.Internal.Encoder_Storage
Giflib.Internal.LZW
Giflib.Internal.LZW_Arithmetic
Giflib.Internal.LZW_Encoding
Giflib.Internal.Metadata_Store
Giflib.Internal.Owned_Arrays
Giflib.Internal.Owned_Buffers
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
