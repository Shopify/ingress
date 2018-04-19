#!/bin/bash

if luarocks list --porcelain busted $BUSTEDVERSION | grep -q "installed"; then
  echo busted already installed, skipping ;
else
  echo busted not found, installing via luarocks...;
  sudo luarocks install busted $BUSTEDVERSION;
fi
