#!/bin/bash

KUBE_VERSION=v1.35.3
ARCH=arm64
    
curl -fsSLO "https://dl.k8s.io/${KUBE_VERSION?}/bin/linux/${ARCH?}/kubelet"

sudo install -m 755 kubelet /usr/local/bin
