#!/bin/sh
set -eu

root=${1:-..}
manifest=$(mktemp)
trap 'rm -f "$manifest"' EXIT HUP INT TERM

upward_dependencies=$(
    find "$root/src" -type f \
      \( -name 'giflib-internal-*.ads' -o -name 'giflib-internal-*.adb' \) \
      -exec awk '
        {
          line = $0
          sub(/--.*/, "", line)
          statement = statement " " line
          while (index(statement, ";") != 0) {
            stop = index(statement, ";")
            clause = substr(statement, 1, stop - 1)
            statement = substr(statement, stop + 1)
            gsub(/[[:space:]]+/, " ", clause)
            if (clause ~ /(^| )with Giflib[.](Decoding|Encoding|Quantization)([^[:alnum:]_]|$)/) {
              print FILENAME ":" clause ";"
            }
          }
        }
      ' {} +
)
if [ -n "$upward_dependencies" ]; then
    echo "internal packages depend upward on public codec facades" >&2
    echo "$upward_dependencies" >&2
    exit 1
fi

find "$root/src" -type f \( -name '*.ads' -o -name '*.adb' \) \
  -exec awk '
    {
      line = $0
      sub(/--.*/, "", line)
      statement = statement " " line
      while (index(statement, ";") != 0) {
        stop = index(statement, ";")
        clause = substr(statement, 1, stop - 1)
        statement = substr(statement, stop + 1)
        gsub(/[[:space:]]+/, " ", clause)
        sub(/^ /, "", clause)
        if (clause ~ /^package [[:alnum:]_]+ is new ([[:alnum:]_]+[.])*Owned_(Arrays|Objects)([^[:alnum:]_]|$)/) {
          name = clause
          sub(/^package /, "", name)
          sub(/ .*/, "", name)
          kind = clause
          sub(/^.* is new /, "", kind)
          sub(/^([[:alnum:]_]+[.])*/, "", kind)
          sub(/[^[:alnum:]_].*$/, "", kind)
          file = FILENAME
          sub(/^.*\//, "", file)
          print file ":" name ":" kind
        }
      }
    }
  ' {} + | sort >"$manifest"

if ! cmp -s "$manifest" - <<'EOF'
giflib-internal-lzw.ads:Workspace_Ownership:Owned_Objects
giflib-internal-lzw_encoding.ads:Workspace_Ownership:Owned_Objects
giflib-internal-metadata_store.ads:Extension_Storage:Owned_Arrays
giflib-internal-metadata_store.ads:Payload_Storage:Owned_Arrays
giflib-internal-owned_buffers.ads:Storage:Owned_Arrays
giflib-internal-quantization_storage.ads:Error_Ownership:Owned_Arrays
giflib-internal-quantization_storage.ads:Histogram_Ownership:Owned_Objects
giflib-internal-quantization_storage.ads:Nearest_Cache_Ownership:Owned_Objects
EOF
then
    echo "production ownership-container instances need safety review" >&2
    exit 1
fi

misplaced_subunits=$(
    find "$root/tests/src" -maxdepth 1 -type f -name '*.adb' -exec awk '
      /^[[:space:]]*separate[[:space:]]*[(]/ { print FILENAME; exit }
    ' {} +
)
if [ -n "$misplaced_subunits" ]; then
    echo "test subunits must live under tests/src/subunits" >&2
    echo "$misplaced_subunits" >&2
    exit 1
fi

oversized_tests=$(
    find "$root/tests/src" -maxdepth 1 -type f \
      -name 'giflib-testing-test_*.adb' -exec wc -l {} + |
      awk '$2 != "total" && $1 > 500 { print $2 ":" $1 }'
)
if [ -n "$oversized_tests" ]; then
    echo "test-case parent body exceeds 500 lines" >&2
    echo "$oversized_tests" >&2
    exit 1
fi
