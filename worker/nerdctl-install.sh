#/bin/bash

NERDCTL_VERSION=2.2.1
    
curl -fsSLO "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION?}/nerdctl-${NERDCTL_VERSION?}-linux-arm64.tar.gz"
    
tar xzvof "nerdctl-${NERDCTL_VERSION?}-linux-arm64.tar.gz"
    
sudo install -m 755 nerdctl /usr/local/bin
    
nerdctl completion bash | sudo tee /etc/bash_completion.d/nerdctl
