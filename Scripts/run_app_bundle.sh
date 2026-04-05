#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT_DIR/Scripts/build_app_bundle.sh"
open -n "$ROOT_DIR/Build/OverlayNotes.app"
