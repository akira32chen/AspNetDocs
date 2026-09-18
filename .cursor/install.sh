#!/usr/bin/env bash
# Idempotent Cloud Agent setup for the ASP.NET 4.x DocFX documentation repo.
#
# Installs the toolchain needed to build, lint, and preview the docs:
#   - .NET SDK 8   (required by DocFX 2.80)
#   - DocFX 2.80   (builds and serves the docs site)
#   - markdownlint-cli (matches the repo's committed .markdownlint.json)
#   - a small local-preview template overlay (see step 4)
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive DOTNET_CLI_TELEMETRY_OPTOUT=1

DOCFX_VERSION="2.80.1"
MARKDOWNLINT_VERSION="0.49.1"
PREVIEW_TEMPLATE_DIR="/usr/local/share/docfx-preview-template"

# 1. .NET SDK 8.
if ! dotnet --list-sdks 2>/dev/null | grep -q '^8\.'; then
  sudo apt-get update
  sudo apt-get install -y dotnet-sdk-8.0
fi

# 2. DocFX, installed into a directory that is always on PATH.
if ! command -v docfx >/dev/null 2>&1; then
  sudo env DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    dotnet tool install --tool-path /usr/local/bin docfx --version "$DOCFX_VERSION"
fi

# 3. markdownlint-cli (best-effort; docs build/preview does not depend on it).
if ! command -v markdownlint >/dev/null 2>&1; then
  NPM_BIN="$(command -v npm || true)"
  if [ -n "$NPM_BIN" ]; then
    sudo env "PATH=$PATH" "$NPM_BIN" install -g --prefix /usr/local \
      "markdownlint-cli@$MARKDOWNLINT_VERSION" \
      || echo "WARN: markdownlint-cli install failed; docs linting unavailable"
  else
    echo "WARN: npm not found; skipping markdownlint-cli"
  fi
fi

# 4. Local-preview template overlay.
# DocFX 2.80's default template renders this repo's deeply nested root toc.yml
# fully expanded in the navbar, which pushes the article off-screen. The default
# template loads styles/main.css last, so this overlay collapses the nested
# navbar levels and restores normal article flow. Build with:
#   docfx build docfx.json -t default,/usr/local/share/docfx-preview-template
sudo mkdir -p "$PREVIEW_TEMPLATE_DIR/styles"
sudo tee "$PREVIEW_TEMPLATE_DIR/styles/main.css" >/dev/null <<'CSS'
/* Local preview overlay for the ASP.NET docs (Cloud Agent environment). */
#navbar .navbar-nav .nav { display: none !important; }
.article.grid { position: static !important; }
#_content { position: static !important; }
CSS

echo "Toolchain ready:"
echo "  dotnet        $(dotnet --version)"
echo "  docfx         $(docfx --version | cut -d+ -f1)"
if command -v markdownlint >/dev/null 2>&1; then
  echo "  markdownlint  $(markdownlint --version)"
else
  echo "  markdownlint  (not installed)"
fi
echo "  preview tpl   $PREVIEW_TEMPLATE_DIR"
