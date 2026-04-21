# Kubernetes - The Hard Way

I am gonna be using the course by Márk Sági-Kazár on Iximiuz Labs
called Kubernetes The Very Hard way as my guiding point, which in turn
is based out of Kelsey Hightowers Kubernetes the Hard Way repository.

Apart from using their points I will be trying to use my knowledge to its
best inorder to do it all in one day.

1. VMs setup

  Using LimaCTL to spin up nodes, we are going to use two of them, 1. worker 
  node and 1. control plane node. I want to finish setting it all up in a 
  single day and I have previously never done this so this is only for testing 
  my knowledge and to know whether it is even possible or not.
  
  Using the scripts 
  
  ```
  limactl start --name worker lima-ubuntu-lts-template.yaml
  limactl start --name controlplane lima-ubuntu-lts-template.yaml
  ```

2. Worker Node Setup

    * Container Runtime installation.

    We choose to install containerd as the runtime. 
    We download the runtime as a gz file from github releases, move it to 
    `/usr/local` directory and setup a systemctl config file that containerd
    team provides out of the box along with the releases and save it in
    `/etc/systemd/system` directory.

    Then a simple systemctl daemon-reload and service start should start 
    `containerd`

    ```sh
    wget https://github.com/containerd/containerd/releases/download/v2.2.3/containerd-2.2.3-linux-arm64.tar.gz
    tar -xvf containerd-2.2.3-linux-arm64.tar.gz
    mv bin/ /usr/local

    sudo wget -P /etc/systemd/system "https://raw.githubusercontent.com/containerd/containerd/v2.2.3/containerd.service"
    ```

    ```sh
    sudo systemctl daemon-reload
    sudo systemctl start containerd
    ```

    * NerdCTL installation
    
    While `ctr` tool allows you to interact with containerd and run containers, 
    it is not very user friendly and mostly engineers when you talk about 
    containers are mostly comfortable with Docker CLI. NerdCTL is a utility
    that lets you interact with containerd runtime with Docker CLI's commandline
    options. 

    Spinning up a container with NerdCTL is similar to how you would do it in 
    Docker CLI.
    
    ```sh
    NERDCTL_VERSION=2.2.1
    
    curl -fsSLO "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION?}/nerdctl-${NERDCTL_VERSION?}-linux-arm64.tar.gz"
    
    tar xzvof "nerdctl-${NERDCTL_VERSION?}-linux-arm64.tar.gz"
    
    sudo install -m 755 nerdctl /usr/local/bin
    
    nerdctl completion bash | sudo tee /etc/bash_completion.d/nerdctl
    ```
   
3. Control Plane Setup
4. Connectivity and configurations
