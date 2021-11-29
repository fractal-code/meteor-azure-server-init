#!/bin/bash

# -------------------------------
# Meteor Azure
# Server initialisation script
# Version: 1.3.4
# -------------------------------

BUNDLE_DIR="D:/home/meteor-azure"
BUNDLE_DIR_CMD="${HOME}/meteor-azure"
NVM_VERSION="1.1.7"

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
export NVM_HOME="${BUNDLE_DIR}/nvm"
if [ ! -d "nvm" ]; then mkdir "nvm"; fi
(echo "root: ${BUNDLE_DIR}/nvm" && echo "proxy: none") > "nvm/settings.txt" || error_exit "Could not set NVM settings"
if [ ! -e "nvm/nvm.exe" ] || [ "$(nvm/nvm.exe version)" != "${NVM_VERSION}" ]; then
  print "Installing NVM"
  curl -L -o "nvm-noinstall.zip" \
      "https://github.com/coreybutler/nvm-windows/releases/download/${NVM_VERSION}/nvm-noinstall.zip"
  unzip -o "nvm-noinstall.zip" -d "nvm"
  rm "nvm-noinstall.zip"
fi
if [ "$(nvm/nvm.exe version)" != "${NVM_VERSION}" ]; then error_exit "Could not install NVM"; fi
print "Now using NVM v$(nvm/nvm.exe version)"

# Handle missing Node architecture, maintains backwards compatibility with 32-bit default
if [ "${METEOR_AZURE_NODE_ARCH}" != "64" ]; then METEOR_AZURE_NODE_ARCH="32"; fi

# Install custom Node
print "Setting Node to ${METEOR_AZURE_NODE_VERSION} ${METEOR_AZURE_NODE_ARCH}-bit"
if [ -e "nvm/${METEOR_AZURE_NODE_VERSION}/node.exe" ]; then rm "nvm/${METEOR_AZURE_NODE_VERSION}/node.exe"; fi
nvm/nvm.exe install "${METEOR_AZURE_NODE_VERSION}" "${METEOR_AZURE_NODE_ARCH}"
cp "nvm/${METEOR_AZURE_NODE_VERSION}/node${METEOR_AZURE_NODE_ARCH}.exe" "nvm/${METEOR_AZURE_NODE_VERSION}/node.exe"
export PATH="${BUNDLE_DIR_CMD}/nvm/${METEOR_AZURE_NODE_VERSION}:${PATH}"
if [ "$(node -v)" != "${METEOR_AZURE_NODE_VERSION}" ]; then error_exit "Could not install Node"; fi
print "Now using Node $(node -v) (${METEOR_AZURE_NODE_ARCH}-bit)"

# Install custom NPM
if [ "$(npm -v)" != "${METEOR_AZURE_NPM_VERSION}" ]; then
  print "Setting NPM version"
  # Apply workaround for https://github.com/coreybutler/nvm-windows/issues/300
  pushd "nvm/${METEOR_AZURE_NODE_VERSION}"
  rm npm npx npm.cmd npx.cmd
  cmd //c move "node_modules/npm" "node_modules/npm2" || echo "Found remanent files - resuming installation"
  node "node_modules/npm2/bin/npm-cli.js" i "npm@${METEOR_AZURE_NPM_VERSION}" -g || "Could not install custom NPM"
  rm -rf "node_modules/npm2"
  popd || error_exit "Could not return to working directory"
fi
print "Now using NPM v$(npm -v)"

# Install rimraf tool
if ! hash rimraf 2>/dev/null; then
  print "Installing rimraf tool"
  npm install -g rimraf || error_exit "Could not install rimraf tool"
fi

# Install global node-pre-gyp
print "Installing global node-pre-gyp"
npm install -g @mapbox/node-pre-gyp@^1.0.0 || error_exit "Could not install node-pre-gyp"

# -------------------------------
# Setup
# -------------------------------

cd "${DEPLOYMENT_TEMP}" || error_exit "Could not find working directory"

# Unpack bundle
if [ -d "bundle" ]; then
  print "Clearing old bundle"
  rimraf "bundle" || error_exit "Could not clear old bundle"
fi
print "Unpacking bundle"
tar -xzf "${BUNDLE_DIR_CMD}/bundle.tar.gz" --warning="no-unknown-keyword" || error_exit "Could not unpack bundle"

# Ensure web config is set
if [ ! -e "bundle/web.config" ]; then
  print "Using default web config"
  cp "${DEPLOYMENT_SOURCE}/web.config" "bundle/web.config" || error_exit "Could not set web config"
fi

# Set Node runtime
print "Setting Node runtime"
(echo "nodeProcessCommandLine: ${BUNDLE_DIR}/nvm/${METEOR_AZURE_NODE_VERSION}/node.exe") \
  >> "bundle/iisnode.yml" || error_exit "Could not set Node runtime"

# Enable IISNode logging  
print "Enabling IISNode logging"
(echo "loggingEnabled: true") >> "bundle/iisnode.yml" || error_exit "Could not enable IISNode logging"    

# Install NPM dependencies
print "Installing NPM dependencies"
pushd "bundle/programs/server"
npm install --production || error_exit "Could not install NPM dependencies"
popd || error_exit "Could not return to working directory"

# Rebuild NPM dependencies
print "Rebuilding NPM dependencies"
pushd "bundle/programs/server/npm"
npm rebuild --update-binary || error_exit "Could not rebuild NPM dependencies"
popd || error_exit "Could not return to working directory"

# -------------------------------
# Startup
# -------------------------------

cd "${DEPLOYMENT_TARGET}" || error_exit "Could not find target directory"

# Sync bundle
print "Syncing bundle"
robocopy "${DEPLOYMENT_TEMP}\bundle" "." //mt //mir > /dev/null
if [ "${?}" -ge 8 ]; then error_exit "Could not sync bundle"; fi # handle special robocopy exit codes

print "Finished successfully"
