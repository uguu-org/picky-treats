#!/bin/bash
# Replace colors in PNG image to match GIF colors.

if [[ $# != 2 ]]; then
   echo "$0 {input.png} {output.png}"
   exit 1
fi

set -euo pipefail

pngtopnm "$1" \
   | ppmchange '#312f28' '#342e2c' \
   | ppmchange '#b1afa8' '#b4aeac' \
   | pnmtopng -compression 9 > "$2"
