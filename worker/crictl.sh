#!/bin/bash

CRICTL_VERSION=v1.35.0
ARCH=arm64
      
curl -fsSLO "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION?}/crictl-${CRICTL_VERSION?}-linux-${ARCH?}.tar.gz"
      
sudo tar xzvof "crictl-${CRICTL_VERSION?}-linux-${ARCH?}.tar.gz" -C /usr/local/bin

