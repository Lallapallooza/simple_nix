#!/usr/bin/env bash
# Build and install the Ayu Dark (10-group) theme into VS Code.
#
# VS Code only loads extensions recorded in ~/.vscode/extensions/extensions.json,
# which it writes on install -- a directory or symlink dropped into that folder is
# silently ignored (and gets marked in .obsolete). So the theme has to go in as a
# .vsix through the CLI. Re-run this after editing the theme JSON.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/ayu-dark-10group"

command -v code >/dev/null 2>&1 || { echo "    SKIP: 'code' not on PATH"; exit 0; }

BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/extension"
cp -r "$SRC/." "$BUILD/extension/"

cat > "$BUILD/[Content_Types].xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="json" ContentType="application/json"/><Default Extension="vsixmanifest" ContentType="text/xml"/></Types>
XML

cat > "$BUILD/extension.vsixmanifest" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
  <Metadata>
    <Identity Language="en-US" Id="ayu-dark-10group" Version="1.0.0" Publisher="local" />
    <DisplayName>Ayu Dark (10-group)</DisplayName>
    <Description xml:space="preserve">Ayu Dark with the 10-group syntax system shared by kitty, neovim, wayle, rofi and KDE.</Description>
    <Tags>theme,color-theme</Tags>
    <Categories>Themes</Categories>
    <GalleryFlags>Public</GalleryFlags>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="^1.70.0" />
      <Property Id="Microsoft.VisualStudio.Code.ExtensionKind" Value="ui,workspace,web" />
    </Properties>
  </Metadata>
  <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>
  <Dependencies/>
  <Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true" /></Assets>
</PackageManifest>
XML

python3 - "$BUILD" <<'PY'
import os, sys, zipfile
b = sys.argv[1]
with zipfile.ZipFile(os.path.join(b, "theme.vsix"), "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(b):
        for f in files:
            if f == "theme.vsix":
                continue
            p = os.path.join(root, f)
            z.write(p, os.path.relpath(p, b))
PY

code --install-extension "$BUILD/theme.vsix" --force 2>&1 | grep -viE 'warning|trace-deprecation' || true
echo "    Installed -- reload VS Code (Ctrl+Shift+P > Developer: Reload Window)"
