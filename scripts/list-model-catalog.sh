#!/usr/bin/env bash
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/skills/worker-driven-development/scripts/list-model-catalog.sh" "$@"
