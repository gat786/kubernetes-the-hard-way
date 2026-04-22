#!/bin/bash
KUBELETCTL_VERSION=v1.13
ARCH=arm64
      
curl -fsSLO "https://github.com/cyberark/kubeletctl/releases/download/${KUBELETCTL_VERSION?}/kubeletctl_linux_${ARCH?}"
      
sudo install -m 755 kubeletctl_linux_${ARCH?} /usr/local/bin/kubeletctl

