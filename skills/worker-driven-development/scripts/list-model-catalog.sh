#!/usr/bin/env bash
# Forwarder to list-models.sh
set -euo pipefail
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPTS/list-models.sh" "$@"
