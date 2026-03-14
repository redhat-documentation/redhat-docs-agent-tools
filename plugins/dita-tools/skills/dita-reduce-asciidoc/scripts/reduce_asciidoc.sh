#!/bin/bash
#
# reduce_asciidoc.sh - Flatten AsciiDoc assemblies using asciidoctor-reducer
#
# Usage: reduce_asciidoc.sh <file.adoc> [-o output.adoc]
#
# Exit codes:
#   0 - Success
#   1 - Error (missing input, missing tool, reduction failed)

set -uo pipefail

if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $(basename "$0") <file.adoc> [-o output.adoc]"
    exit 0
fi

INPUT_FILE="$1"
shift

# Parse -o flag
OUTPUT_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: File not found: $INPUT_FILE" >&2
    exit 1
fi

if ! command -v asciidoctor-reducer &> /dev/null; then
    echo "Error: asciidoctor-reducer is not installed. Install with: gem install asciidoctor-reducer" >&2
    exit 1
fi

# Default output: <basename>-reduced.adoc in same directory
if [[ -z "$OUTPUT_FILE" ]]; then
    DIR=$(dirname "$INPUT_FILE")
    BASE=$(basename "$INPUT_FILE" .adoc)
    OUTPUT_FILE="${DIR}/${BASE}-reduced.adoc"
fi

asciidoctor-reducer --preserve-conditionals "$INPUT_FILE" -o "$OUTPUT_FILE"
echo "Wrote: $OUTPUT_FILE"
