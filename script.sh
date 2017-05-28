#!/bin/bash

# -------------------------------
# Meteor Azure
# Server initialisation script
# Version: 1.0.1
# -------------------------------

BUNDLE_DIR="D:/home/meteor-azure"
BUNDLE_DIR_CMD="${HOME}/meteor-azure"
NVM_VERSION="1.1.4"

function print { echo "meteor-azure: ${1}"; }

function error_exit {
  # Display error message and exit
  echo "meteor-azure: ${1:-"Unknown Error"}" 1>&2
  exit 1
}

# -------------------------------
# Prerequisites
# -------------------------------

cd "${BUNDLE_DIR}" || error_exit "Could not find bundle directory"

# Install NVM
if [ ! -e "nvm/nvm.exe" ]; then
  print "Installing NVM"
  curl -L -o "nvm-noinstall.zip" \
      "https://github.com/coreybutler/nvm-windows/releases/download/${NVM_VERSION}/nvm-noinstall.zip"
  unzip "nvm-noinstall.zip" -d "nvm"
  rm "nvm-noinstall.zip"
fi
(echo "root: ${BUNDLE_DIR}/nvm" && echo "proxy: none") > "nvm/settings.txt" || error_exit "Could not set NVM settings"
export NVM_HOME="${BUNDLE_DIR}/nvm"
if [ "$(nvm/nvm.exe version)" != "${NVM_VERSION}" ]; then error_exit "Could not install NVM"; fi
print "Now using NVM v$(nvm/nvm.exe version)"

# Install custom Node
print "Setting Node version"
nvm/nvm.exe install "${METEOR_AZURE_NODE_VERSION}" 32
if [ ! -e "nvm/${METEOR_AZURE_NODE_VERSION}/node.exe" ]; then
  cp "nvm/${METEOR_AZURE_NODE_VERSION}/node32.exe" "nvm/${METEOR_AZURE_NODE_VERSION}/node.exe"
fi
export PATH="${BUNDLE_DIR_CMD}/nvm/${METEOR_AZURE_NODE_VERSION}:${PATH}"
if [ "$(node -v)" != "${METEOR_AZURE_NODE_VERSION}" ]; then error_exit "Could not install Node"; fi
print "Now using Node $(node -v) (32-bit)"

# Install custom NPM
if [ "$(npm -v)" != "${METEOR_AZURE_NPM_VERSION}" ]; then
  print "Setting NPM version"
  cmd //c npm install -g "npm@${METEOR_AZURE_NPM_VERSION}" || error_exit "Could not install NPM"
fi
print "Now using NPM v$(npm -v)"

# Install JSON tool
if ! hash json 2>/dev/null; then
  print "Installing JSON tool"
  npm install -g json || error_exit "Could not install JSON tool"
fi

# Install rimraf tool
if ! hash rimraf 2>/dev/null; then
  print "Installing rimraf tool"
  npm install -g rimraf || error_exit "Could not install rimraf tool"
fi

# -------------------------------
# Configuration
# -------------------------------

cd "${DEPLOYMENT_TEMP}" || error_exit "Could not find working directory"

# Unpack bundle
if [ -d "bundle" ]; then
  print "Clearing old bundle"
  rimraf "bundle" || error_exit "Could not clear old bundle"
fi
print "Unpacking bundle"
tar -xzf "${BUNDLE_DIR_CMD}/bundle.tar.gz" || error_exit "Could not unpack bundle"

# Ensure web config is set
if [ ! -e "bundle/web.config" ]; then
  print "Using default web config"
  cp "${DEPLOYMENT_SOURCE}/web.config" "bundle/web.config" || error_exit "Could not set web config"
fi

# Set Node runtime
print "Setting Node runtime"
(echo "nodeProcessCommandLine: ${BUNDLE_DIR}/nvm/${METEOR_AZURE_NODE_VERSION}/node.exe") > "bundle/iisnode.yml" \
    || error_exit "Could not set Node runtime"

# -------------------------------
# Startup
# -------------------------------

cd "${DEPLOYMENT_TARGET}" || error_exit "Could not find target directory"

# Sync bundle
print "Syncing bundle"
robocopy "${DEPLOYMENT_TEMP}\bundle" "." //mt //mir > /dev/null
if [ $? -ge 8 ]; then error_exit "Could not sync bundle"; fi # handle special robocopy exit codes

# Install NPM dependencies
print "Installing NPM dependencies"
pushd "programs/server"
npm install --production || error_exit "Could not install NPM dependencies"
popd || error_exit "Could not return to target directory"

# Rebuild NPM dependencies
print "Rebuilding NPM dependencies"
pushd "programs/server/npm"
npm rebuild --update-binary || error_exit "Could not rebuild NPM dependencies"
popd || error_exit "Could not return to target directory"

print "Finished successfully"
