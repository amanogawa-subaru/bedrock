#!/usr/bin/env bash

# Bedrock installer

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USERNAME="$(whoami)"

CONFIG="/etc/nixos/configuration.nix"
PORTAL_DIR="/etc/nixos"
PORTAL="$PORTAL_DIR/flake.nix"

PROFILES_FILE="$REPO_DIR/profiles.nix"
PROFILES_DIR="$HOME/nixos-profiles"

echo "Welcome to the Bedrock + profiles installer!"
echo
echo "User: $USERNAME"
echo "Repo: $REPO_DIR"

# --- Safety checks ---

if [[ "$(id -u)" -eq 0 ]]; then
  echo
  echo "Error: Do not run this installer as root."
  echo "Run it as your normal user instead."
  exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
  echo
  echo "Error: $CONFIG does not exist."
  echo "Bedrock expects an existing NixOS installation."
  exit 1
fi

if [[ ! -f "$PROFILES_FILE" ]]; then
  echo
  echo "Error: $PROFILES_FILE does not exist."
  exit 1
fi

# --- PCI bus ID conversion ---

pci_to_nix_bus_id() {
  local pci_address="$1"

  # Remove PCI domain.
  local address="${pci_address#*:}"

  local bus="${address%%:*}"
  local rest="${address#*:}"

  local device="${rest%%.*}"
  local function="${rest#*.}"

  printf 'PCI:%d:%d:%d' \
    "$((16#$bus))" \
    "$((16#$device))" \
    "$((16#$function))"
}

# --- Detect graphics hardware ---

echo
echo "Detecting graphics hardware..."

NVIDIA=false
NVIDIA_PRIME=false

NVIDIA_DEVICE=""
INTEL_DEVICE=""
AMD_DEVICE=""

NVIDIA_BUS_ID=""
IGPU_BUS_ID=""
PRIME_IGPU=""

for DEVICE in /sys/bus/pci/devices/*; do
  [[ -f "$DEVICE/vendor" ]] || continue
  [[ -f "$DEVICE/class" ]] || continue

  VENDOR="$(<"$DEVICE/vendor")"
  CLASS="$(<"$DEVICE/class")"

  # PCI class 0x03xxxx = display controller.
  [[ "$CLASS" == 0x03* ]] || continue

  PCI_ADDRESS="${DEVICE##*/}"

  case "$VENDOR" in
    # NVIDIA
    0x10de)
      if [[ -z "$NVIDIA_DEVICE" ]]; then
        NVIDIA_DEVICE="$PCI_ADDRESS"
      fi
      ;;

    # Intel
    0x8086)
      if [[ -z "$INTEL_DEVICE" ]]; then
        INTEL_DEVICE="$PCI_ADDRESS"
      fi
      ;;

    # AMD / ATI
    0x1002)
      if [[ -z "$AMD_DEVICE" ]]; then
        AMD_DEVICE="$PCI_ADDRESS"
      fi
      ;;
  esac
done

# --- NVIDIA detection ---

if [[ -n "$NVIDIA_DEVICE" ]]; then
  NVIDIA=true

  NVIDIA_BUS_ID="$(
    pci_to_nix_bus_id "$NVIDIA_DEVICE"
  )"

  echo "NVIDIA GPU detected:"
  echo "  PCI device: $NVIDIA_DEVICE"
  echo "  Bus ID:     $NVIDIA_BUS_ID"
else
  echo "No NVIDIA GPU detected."
fi

# --- Laptop detection ---

HAS_BATTERY=false

for BATTERY in /sys/class/power_supply/BAT*; do
  if [[ -e "$BATTERY" ]]; then
    HAS_BATTERY=true
    break
  fi
done

# --- PRIME detection ---

if [[ "$NVIDIA" == true ]] &&
   [[ "$HAS_BATTERY" == true ]]; then

  if [[ -n "$INTEL_DEVICE" ]]; then
    NVIDIA_PRIME=true
    PRIME_IGPU="intel"

    IGPU_BUS_ID="$(
      pci_to_nix_bus_id "$INTEL_DEVICE"
    )"

  elif [[ -n "$AMD_DEVICE" ]]; then
    NVIDIA_PRIME=true
    PRIME_IGPU="amd"

    IGPU_BUS_ID="$(
      pci_to_nix_bus_id "$AMD_DEVICE"
    )"
  fi
fi

if [[ "$NVIDIA_PRIME" == true ]]; then
  echo
  echo "Hybrid NVIDIA laptop detected."

  if [[ "$PRIME_IGPU" == "intel" ]]; then
    echo "Integrated GPU: Intel"
  else
    echo "Integrated GPU: AMD"
  fi

  echo "  iGPU Bus ID:   $IGPU_BUS_ID"
  echo "  NVIDIA Bus ID: $NVIDIA_BUS_ID"

elif [[ "$NVIDIA" == true ]]; then
  echo
  echo "NVIDIA GPU detected without hybrid PRIME configuration."
fi

# --- Generate settings.nix ---

SETTINGS_FILE="$REPO_DIR/settings.nix"

cat > "$SETTINGS_FILE" <<EOF
{
  username = "$USERNAME";

  nvidia = $NVIDIA;
  nvidiaPrime = $NVIDIA_PRIME;

  primeIGPU = "$PRIME_IGPU";
  igpuBusId = "$IGPU_BUS_ID";
  nvidiaBusId = "$NVIDIA_BUS_ID";
}
EOF

echo
echo "Generated settings.nix"

# --- Generate local user packages ---

USER_PACKAGES="$REPO_DIR/modules/user-packages.nix"
USER_PACKAGES_EXAMPLE="$REPO_DIR/modules/user-packages.example.nix"

if [[ ! -f "$USER_PACKAGES" ]]; then
  if [[ ! -f "$USER_PACKAGES_EXAMPLE" ]]; then
    echo
    echo "Error: $USER_PACKAGES_EXAMPLE does not exist."
    exit 1
  fi

  cp "$USER_PACKAGES_EXAMPLE" "$USER_PACKAGES"

  echo
  echo "Generated user-packages.nix"
else
  echo
  echo "Existing user-packages.nix preserved."
fi

# --- Generate local mounts ---

MOUNT_CONFIG="$REPO_DIR/modules/mount.nix"
MOUNT_EXAMPLE="$REPO_DIR/modules/mount.example.nix"

if [[ ! -f "$MOUNT_CONFIG" ]]; then
  if [[ ! -f "$MOUNT_EXAMPLE" ]]; then
    echo
    echo "Error: $MOUNT_EXAMPLE does not exist."
    exit 1
  fi

  cp "$MOUNT_EXAMPLE" "$MOUNT_CONFIG"

  echo
  echo "Generated mount.nix"
else
  echo
  echo "Existing mount.nix preserved."
fi

# --- Read profile catalog ---

mapfile -t PROFILE_IDS < <(
  nix eval \
    --impure \
    --raw \
    --expr '
      let
        profiles = import '"$PROFILES_FILE"';
      in
        builtins.concatStringsSep "\n" (builtins.attrNames profiles)
    '
)

if [[ "${#PROFILE_IDS[@]}" -eq 0 ]]; then
  echo
  echo "Error: No profiles are available."
  exit 1
fi

echo
echo "Available profiles:"
echo

for i in "${!PROFILE_IDS[@]}"; do
  id="${PROFILE_IDS[$i]}"

  name="$(
    nix eval \
      --impure \
      --raw \
      --expr "(import $PROFILES_FILE).${id}.name"
  )"

  description="$(
    nix eval \
      --impure \
      --raw \
      --expr "(import $PROFILES_FILE).${id}.description"
  )"

  printf '  %d) %s - %s\n' "$((i + 1))" "$name" "$description"
done

# --- Profile selector ---

echo

while true; do
  read -rp "Select a profile [1-${#PROFILE_IDS[@]}]: " selection

  if [[ "$selection" =~ ^[0-9]+$ ]] &&
     (( selection >= 1 && selection <= ${#PROFILE_IDS[@]} )); then
    break
  fi

  echo "Invalid selection."
done

selected_id="${PROFILE_IDS[$((selection - 1))]}"

selected_name="$(
  nix eval \
    --impure \
    --raw \
    --expr "(import $PROFILES_FILE).${selected_id}.name"
)"

selected_repo="$(
  nix eval \
    --impure \
    --raw \
    --expr "(import $PROFILES_FILE).${selected_id}.repo"
)"

target_dir="$PROFILES_DIR/$selected_id"

echo
echo "Selected profile: $selected_name"
echo "Repository: $selected_repo"
echo "Install path: $target_dir"

# --- Install selected profile ---

if [[ -e "$target_dir" ]]; then
  if [[ ! -d "$target_dir" ]] ||
     [[ ! -f "$target_dir/flake.nix" ]]; then

    echo
    echo "Error: $target_dir exists but is not a valid profile checkout."
    exit 1
  fi

  echo
  echo "Existing $selected_name profile preserved."

else
  mkdir -p "$PROFILES_DIR"

  echo
  echo "Installing $selected_name..."

  git clone "$selected_repo" "$target_dir"

  echo
  echo "Profile installed successfully:"
  echo "  $target_dir"
fi

# --- Discover installed profiles ---

INSTALLED_PROFILE_IDS=()

if [[ -d "$PROFILES_DIR" ]]; then
  for profile_dir in "$PROFILES_DIR"/*; do
    [[ -d "$profile_dir" ]] || continue

    profile_id="${profile_dir##*/}"

    if [[ ! -f "$profile_dir/flake.nix" ]]; then
      echo
      echo "Error: Installed profile directory has no flake.nix:"
      echo "  $profile_dir"
      exit 1
    fi

    INSTALLED_PROFILE_IDS+=("$profile_id")
  done
fi

if [[ "${#INSTALLED_PROFILE_IDS[@]}" -eq 0 ]]; then
  echo
  echo "Error: No installed profiles were found."
  exit 1
fi

echo
echo "Installed profiles:"

for profile_id in "${INSTALLED_PROFILE_IDS[@]}"; do
  echo "  $profile_id"
done

# --- Back up conflicting browser profile indexes ---

backup_browser_profile() {
  local file="$1"

  if [[ -f "$file" ]] && [[ ! -L "$file" ]]; then
    local backup="${file}.pre-bedrock"

    if [[ -e "$backup" ]]; then
      echo
      echo "Error: $file conflicts with Home Manager,"
      echo "but $backup already exists."
      echo "Refusing to overwrite either file."
      exit 1
    fi

    mv "$file" "$backup"

    echo
    echo "Backed up existing browser profile:"
    echo "  $file"
    echo "  -> $backup"
  fi
}

backup_browser_profile \
  "$HOME/.config/mozilla/firefox/profiles.ini"

backup_browser_profile \
  "$HOME/.librewolf/profiles.ini"

# --- Check existing portal ---

PORTAL_MARKER="# Generated by Bedrock"

if [[ -f "$PORTAL" ]]; then
  if grep -Fq "$PORTAL_MARKER" "$PORTAL"; then
    echo
    echo "Existing Bedrock portal detected."
    echo "Updating portal configuration."

   else
    echo
    echo "Error: $PORTAL already exists and was not generated by Bedrock."
    echo "Refusing to overwrite an existing NixOS flake."
    echo
    echo "Your existing flake has been left untouched."
    exit 1
  fi
fi

# --- Generate composition portal ---

PORTAL_TMP="$(mktemp)"
trap 'rm -f "$PORTAL_TMP"' EXIT

cat > "$PORTAL_TMP" <<EOF
$PORTAL_MARKER
{
  description = "NixOS profile composition portal";

  inputs = {
    bedrock.url = "path:$REPO_DIR";

EOF

for profile_id in "${INSTALLED_PROFILE_IDS[@]}"; do
  profile_path="$PROFILES_DIR/$profile_id"

  cat >> "$PORTAL_TMP" <<EOF
    $profile_id = {
      url = "path:$profile_path";
      inputs.nixpkgs.follows = "bedrock/nixpkgs";
    };

EOF
done

cat >> "$PORTAL_TMP" <<'EOF'
  };

  outputs = inputs@{ bedrock, ... }: {
    nixosConfigurations = {
EOF

for profile_id in "${INSTALLED_PROFILE_IDS[@]}"; do
  cat >> "$PORTAL_TMP" <<EOF
      $profile_id =
        bedrock.inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./configuration.nix

            bedrock.nixosModules.default
            inputs.$profile_id.nixosModules.default

            ({ username, ... }: {
              home-manager.users.\${username}.imports = [
                bedrock.homeModules.default
              ];
            })
          ];
        };

EOF
done

cat >> "$PORTAL_TMP" <<'EOF'
    };
  };
}
EOF

sudo install -m 0644 "$PORTAL_TMP" "$PORTAL"

echo
echo "Portal configured at:"
echo "  $PORTAL"

echo
echo "Bedrock portal generation complete."

# --- Validate configuration ---

echo
echo "Validating $selected_name configuration..."

sudo nixos-rebuild dry-build \
  --flake "$PORTAL_DIR#$selected_id" \
  --no-write-lock-file \
  --option experimental-features "nix-command flakes"

echo
echo "$selected_name configuration validated successfully."

# --- Activate configuration ---

echo
echo "Activating $selected_name..."

sudo nixos-rebuild switch \
  --flake "$PORTAL_DIR#$selected_id" \
  --no-write-lock-file \
  --option experimental-features "nix-command flakes"

echo
echo "Bedrock installation complete."
echo "Active profile: $selected_name"
