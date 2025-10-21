#!/bin/bash

set -e

# ---- Colors ----
GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
RESET="\033[0m"

# ---- Dependency Checks ----

echo -e "${CYAN}Checking for required dependencies...${RESET}"

if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is not installed. Please install git before running this script.${RESET}"
    exit 1
fi

if ! command -v yay &> /dev/null; then
    echo -e "${CYAN}yay is not installed. Installing yay...${RESET}"

    sudo pacman -S --needed --noconfirm git base-devel

    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd -
    rm -rf /tmp/yay

    if ! command -v yay &> /dev/null; then
        echo -e "${RED}Error: Failed to install yay.${RESET}"
        exit 1
    fi

    echo -e "${GREEN}yay has been successfully installed.${RESET}"
else
    echo -e "${GREEN}yay is already installed.${RESET}"
fi

# ---- Clone Omarchy ----

echo -e "${CYAN}Cloning Omarchy repository...${RESET}"
if ! git clone https://www.github.com/basecamp/omarchy ../omarchy; then
    echo -e "${RED}Error: Failed to clone Omarchy repo.${RESET}"
    exit 1
fi

echo -e "${GREEN}Successfully cloned Omarchy repository.${RESET}"

# ---- Add Omarchy Repo to pacman.conf ----

echo -e "${CYAN}Adding Omarchy repository to pacman.conf...${RESET}"

echo -e "\n[omarchy]\nSigLevel = Optional TrustedOnly\nServer = https://pkgs.omarchy.org/\$arch" | sudo tee -a /etc/pacman.conf > /dev/null
sudo pacman -Syu

# ---- Prompt for User Info ----

echo ""
echo -e "${CYAN}Please enter your username:${RESET}"
read -r OMARCHY_USER_NAME
export OMARCHY_USER_NAME

echo ""
echo -e "${CYAN}Please enter your email address:${RESET}"
read -r OMARCHY_USER_EMAIL
export OMARCHY_USER_EMAIL

# ---- Modify Omarchy Scripts for CachyOS ----

echo ""
echo -e "${CYAN}Making adjustments to Omarchy install scripts to support CachyOS...${RESET}"

cd ../omarchy

# 1. Remove tldr to prevent conflict with tealdeer
sed -i '/tldr/d' install/omarchy-base.packages

# 2. Remove conflicting scripts
sed -i '/run_logged \$OMARCHY_INSTALL\/preflight\/pacman\.sh/d' install/preflight/all.sh
sed -i '/run_logged \$OMARCHY_INSTALL\/config\/hardware\/nvidia\.sh/d' install/config/all.sh
sed -i '/run_logged \$OMARCHY_INSTALL\/login\/plymouth\.sh/d' install/login/all.sh
sed -i '/run_logged \$OMARCHY_INSTALL\/login\/limine-snapper\.sh/d' install/login/all.sh
sed -i '/run_logged \$OMARCHY_INSTALL\/login\/alt-bootloaders\.sh/d' install/login/all.sh
sed -i '/run_logged \$OMARCHY_INSTALL\/post-install\/pacman\.sh/d' install/post-install/all.sh

# 3. Adjust mise activation based on shell
sed -i 's/if command -v mise &> \/dev\/null; then/if [ "$SHELL" = "\/bin\/bash" ] \&\& command -v mise \&> \/dev\/null; then/' config/uwsm/env

sed -i '/eval "\$(mise activate bash)"/a\
elif [ "$SHELL" = "\/bin\/fish" ] && command -v mise &> /dev/null; then\
  mise activate fish | source' config/uwsm/env

# ---- Copy Files to ~/.local/share/omarchy ----

echo -e "${CYAN}Installing Omarchy to ~/.local/share/omarchy...${RESET}"

mkdir -p "$HOME/.local/share/omarchy"

# Enable dotglob to copy hidden files (excluding . and ..)
shopt -s dotglob nullglob
cp -r ./* "$HOME/.local/share/omarchy"
shopt -u dotglob nullglob

cd "$HOME/.local/share/omarchy"

# ---- Notify and Confirm ----

echo ""
echo -e "${GREEN}The following adjustments have been made:${RESET}"
echo " 1. Added Omarchy repo to pacman.conf"
echo " 2. Removed tldr from package list to avoid conflict with tealdeer"
echo " 3. Disabled Omarchy scripts that conflict with CachyOS"
echo " 4. Added fish shell support for mise"
echo ""
echo -e "${CYAN}IMPORTANT:${RESET} If you installed CachyOS without a desktop environment, you likely lack a display manager."
echo "To configure Omarchy's Hyprland desktop to start automatically, run:"
echo -e "${GREEN}  ~/.local/share/omarchy/install/login/plymouth.sh${RESET}"
echo ""
echo "Press Enter to begin installing Omarchy..."
read -r

# ---- Start Omarchy Installation ----

chmod +x install.sh
./install.sh
