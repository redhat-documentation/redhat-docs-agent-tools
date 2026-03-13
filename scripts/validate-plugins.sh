#!/bin/bash
#
# validate-plugins.sh
#
# Validates script syntax (Ruby, Python, Shell) across all plugins.
# Plugin structure and frontmatter validation is handled by claudelint in the CI.

set -uo pipefail

if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

ERRORS=0
WARNINGS=0
PASSED=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++)) || true
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++)) || true
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((ERRORS++)) || true
}

validate_ruby() {
    local script="$1"
    local name
    name=$(basename "$script")

    if ruby -c "$script" >/dev/null 2>&1; then
        log_pass "$name: valid Ruby syntax"
    else
        log_error "$name: invalid Ruby syntax"
    fi
}

validate_python() {
    local script="$1"
    local name
    name=$(basename "$script")

    if python3 -m py_compile "$script" 2>/dev/null; then
        log_pass "$name: valid Python syntax"
    else
        log_error "$name: invalid Python syntax"
    fi
}

validate_shell() {
    local script="$1"
    local name
    name=$(basename "$script")

    if bash -n "$script" 2>/dev/null; then
        log_pass "$name: valid shell syntax"
    else
        log_error "$name: invalid shell syntax"
    fi
}

main() {
    echo "Validating scripts in: $REPO_ROOT/plugins"
    echo ""

    local found=0

    while IFS= read -r script; do
        validate_ruby "$script"
        ((found++)) || true
    done < <(find "$REPO_ROOT/plugins" -name "*.rb" -type f 2>/dev/null)

    while IFS= read -r script; do
        validate_python "$script"
        ((found++)) || true
    done < <(find "$REPO_ROOT/plugins" -name "*.py" -type f 2>/dev/null)

    while IFS= read -r script; do
        validate_shell "$script"
        ((found++)) || true
    done < <(find "$REPO_ROOT/plugins" -name "*.sh" -type f 2>/dev/null)

    echo ""
    echo -e "Scripts checked: $found"
    echo -e "  ${GREEN}Passed:${NC}   $PASSED"
    echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
    echo -e "  ${RED}Errors:${NC}   $ERRORS"

    if [[ $ERRORS -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
