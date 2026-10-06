#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 -m http.server "${1:-4173}" --bind 0.0.0.0 --directory mockup
