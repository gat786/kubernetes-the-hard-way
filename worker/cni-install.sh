#!/bin/bash
ARCH=arm64
CNI_PLUGINS_VERSION=v1.9.1
    
curl -fsSLO "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION?}/cni-plugins-linux-${ARCH?}-${CNI_PLUGINS_VERSION?}.tgz"
    
sudo mkdir -p /opt/cni/bin
    
sudo tar xzvofC "cni-plugins-linux-${ARCH?}-${CNI_PLUGINS_VERSION?}.tgz" /opt/cni/bin

