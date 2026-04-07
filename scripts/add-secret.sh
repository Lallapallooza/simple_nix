#!/usr/bin/env bash
set -euo pipefail

sedi() {
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_DIR="${SCRIPT_DIR}/../nixos/secrets"
SECRETS_NIX="${SECRETS_DIR}/secrets.nix"
SECURITY_NIX="${SCRIPT_DIR}/../nixos/security.nix"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <secret-name>"
  echo ""
  echo "Examples:"
  echo "  $0 openai-key          # add an API key"
  echo "  $0 id_ed25519_gitlab   # add an SSH key"
  exit 1
fi

SECRET_NAME="$1"

# Validate secret name to prevent path traversal and sed injection
if [[ ! "$SECRET_NAME" =~ ^[a-z0-9_-]+$ ]]; then
  echo "ERROR: secret name must match [a-z0-9_-]+ (got: ${SECRET_NAME})"
  exit 1
fi

SECRET_FILE="${SECRETS_DIR}/${SECRET_NAME}.age"

# Check age is available
if ! command -v age &>/dev/null; then
  echo "ERROR: 'age' not found. Run: nix-shell -p age"
  exit 1
fi

if [[ -f "$SECRET_FILE" ]]; then
  read -rp "Secret '${SECRET_NAME}.age' already exists. Overwrite? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# Extract variable name → key value pairs from the let block in secrets.nix.
# This keeps variable names and encryption keys in sync (fixes independent extraction bug).
declare -A KEY_MAP
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*\"(.+)\"\;$ ]]; then
    KEY_MAP["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
  fi
done < "$SECRETS_NIX"

if [[ ${#KEY_MAP[@]} -eq 0 ]]; then
  echo "ERROR: no recipient keys found in ${SECRETS_NIX}"
  exit 1
fi

RECIPIENT_VARS=("${!KEY_MAP[@]}")
RECIPIENTS=()
for var in "${RECIPIENT_VARS[@]}"; do
  RECIPIENTS+=("${KEY_MAP[$var]}")
done

RECIPIENT_LIST=$(printf '%s ' "${RECIPIENT_VARS[@]}")

echo "Encrypting for ${#RECIPIENTS[@]} recipient(s): ${RECIPIENT_VARS[*]}"
echo ""

# Read secret value securely.
# Supports multi-line secrets (SSH keys, JSON credentials): type/paste, then Ctrl+D.
echo "Paste the secret value (hidden), then press Ctrl+D on a new line:"
trap 'stty echo 2>/dev/null' EXIT INT TERM
stty -echo 2>/dev/null || true
SECRET_VALUE=$(cat)
stty echo 2>/dev/null || true
trap - EXIT INT TERM
echo ""

if [[ -z "$SECRET_VALUE" ]]; then
  echo "ERROR: empty secret"
  exit 1
fi

# Build age recipient flags
AGE_ARGS=()
for r in "${RECIPIENTS[@]}"; do
  AGE_ARGS+=(-r "$r")
done

# Encrypt (printf avoids trailing newline that echo would add)
printf '%s' "$SECRET_VALUE" | age "${AGE_ARGS[@]}" -o "$SECRET_FILE"
unset SECRET_VALUE
echo ""
echo "Encrypted: nixos/secrets/${SECRET_NAME}.age"

# Add to secrets.nix if not already there
if ! grep -q "\"${SECRET_NAME}.age\"" "$SECRETS_NIX"; then
  local_backup=$(cat "$SECRETS_NIX")
  sedi "s|}$|  \"${SECRET_NAME}.age\".publicKeys = [ ${RECIPIENT_LIST}];\n}|" "$SECRETS_NIX"
  if ! grep -q "\"${SECRET_NAME}.age\"" "$SECRETS_NIX"; then
    echo "WARNING: failed to add entry to secrets.nix -- restoring backup"
    echo "$local_backup" > "$SECRETS_NIX"
  else
    echo "Added to: nixos/secrets/secrets.nix"
  fi
fi

# Add to security.nix if not already there
if ! grep -q "age.secrets.${SECRET_NAME}" "$SECURITY_NIX"; then
  BLOCK="  age.secrets.${SECRET_NAME} = {\n    file = ./secrets/${SECRET_NAME}.age;\n    owner = host.username;\n    group = \"users\";\n    mode = \"0600\";\n  };"
  local_backup=$(cat "$SECURITY_NIX")
  # Insert before the first networking.firewall line
  sedi "/networking\.firewall/i\\${BLOCK}" "$SECURITY_NIX"
  if ! grep -q "age.secrets.${SECRET_NAME}" "$SECURITY_NIX"; then
    echo "WARNING: failed to add entry to security.nix -- restoring backup"
    echo "$local_backup" > "$SECURITY_NIX"
  else
    echo "Added to: nixos/security.nix"
    echo ""
    echo "Secret will be available at: /run/agenix/${SECRET_NAME}"
    echo ""
    echo "To use as an env var in a service:"
    echo "  systemd.services.my-service.serviceConfig.EnvironmentFile = config.age.secrets.${SECRET_NAME}.path;"
    echo ""
    echo "To read in shell:"
    echo "  export MY_VAR=\$(cat /run/agenix/${SECRET_NAME})"
  fi
fi

echo ""
echo "Run to apply: ./install.sh"
