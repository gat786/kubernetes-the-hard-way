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
    
    * ContainerD installation

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
    
  
    * CNI installation
      
      CNI is a specification and set of libraries for configuring network interfaces in Linux containers. It provides a standardized way for container runtimes to set up container networking, including creating network namespaces, configuring IP addresses, and establishing connectivity between containers and the host system.
  
      ```sh
      ARCH=arm64
      CNI_PLUGINS_VERSION=v1.9.1
      
      curl -fsSLO "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION?}/cni-plugins-linux-${ARCH?}-${CNI_PLUGINS_VERSION?}.tgz"
      
      sudo mkdir -p /opt/cni/bin
      
      sudo tar xzvofC "cni-plugins-linux-${ARCH?}-${CNI_PLUGINS_VERSION?}.tgz" /opt/cni/bin
      ```
    
  * Kubelet Setup
    
    Kubelet is an agent which runs on every node, communicates with kubeapi 
    server and makes sure that the machine on which it is running is available
    appropriately to the control plane such that control plane can deploy 
    containers to it if need be and also notifies statuses of currently running
    pods on it to the api-server.
  
    ```sh
    KUBE_VERSION=v1.35.3
    ARCH=arm64
    
    curl -fsSLO "https://dl.k8s.io/${KUBE_VERSION?}/bin/linux/${ARCH?}/kubelet"
    
    sudo install -m 755 kubelet /usr/local/bin
    ```
  
  
    Install the systemd service for kubelet, so that kubelet can be started as an
    init process by systemd
  
    ```ini 
    # kubelet.service file
    [Unit]
    Description=Kubernetes Kubelet
    Documentation=https://kubernetes.io
    After=containerd.service
    Requires=containerd.service
    
    [Service]
    Type=notify
    
    ExecStart=/usr/local/bin/kubelet --config-dir=/var/lib/kubelet/config.d/
    
    ExecStartPre=-/bin/mkdir -p /var/lib/kubelet/config.d/
    
    Restart=on-failure
    RestartSec=3
    
    [Install]
    WantedBy=multi-user.target
    ```
  
    We have specified the configuration directory in which config files
    need to be stored for kubelet to work properly and we have to provide
    them in such a way that kubelet works without the need for control plane
    as of now because the control plane does not exists for now.
    
    ```sh
    sudo mkdir -p /var/lib/kubelet/config.d
    sudo vim -p /var/lib/kubelet/config.d/99-cri.conf
    ```
    
    Making sure kubelet uses our containerd installation
    ```yaml
    apiVersion: kubelet.config.k8s.io/v1beta1
    kind: KubeletConfiguration
    
    containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock
    cgroupDriver: systemd
    ```
    
    Making sure kubelet's api is available without auth, so that we can check if its
    healthy or not.
    ```yaml
    apiVersion: kubelet.config.k8s.io/v1beta1
    kind: KubeletConfiguration
    authentication:
      anonymous:
        enabled: true
      webhook:
        enabled: false
    authorization:
      mode: AlwaysAllow
    ```
    
    Providing static yamls paths to kubelet
    ```yaml
    apiVersion: kubelet.config.k8s.io/v1beta1
    kind: KubeletConfiguration
    
    staticPodPath: /etc/kubernetes/manifests
    ```
  
    Once static pods directory is setup we can create a manifest to be in 
    static pods directory and kubelet will make sure that those pods are running
    on our node. Lets create one;
  
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: podinfo
    spec:
      hostNetwork: true
      containers:
        - name: podinfo
          image: ghcr.io/stefanprodan/podinfo:latest
          ports:
            - containerPort: 9898
    ```
  
    You can check the status/info about this pod by querying kubelet's rest api
    which we made available without auth in the previous step.
  
    ```sh
    curl -k https://localhost:10250/pods | jq ".items[0].metadata"
    ```
    
    Since kubelet uses namespaces to segregate deployments of pods you can actually
    see the deployment using nerdctl and specifying namespace in which the pod
    was deployed. You can do this by first getting namespace name via ctr
  
    ```sh
    sudo ctr namespaces ls
    ```
  
    and then listing pods within that namespace name to nerdctl cli
  
    ```sh
    sudo nerdctl ps --namespace k8s.io
    ```
  
    You will notice that we have `hostNetwork: true` in the podSpec. It means 
    that the ports that are exposed by the pod will also be available on nodes
    port of the exact same numbers. If you turn that off then you will need to
    read the response coming from kubelet api, find the ip which was attached to
    this specific pod and then query that podIP to get a response from that pod.
  
    * Crictl
      
      CriCTL is a tool that can help you inspect and debug containers and images
      managed by kubelet
      
      ```sh
      # crictl does not have patch releases
      CRICTL_VERSION=v1.35.0
      ARCH=arm64
      
      curl -fsSLO "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION?}/crictl-${CRICTL_VERSION?}-linux-${ARCH?}.tar.gz"
      
      sudo tar xzvof "crictl-${CRICTL_VERSION?}-linux-${ARCH?}.tar.gz" -C /usr/local/bin
      ```
    
      Inorder for crictl to correctly interact with our containerd installation
      we create a crictl yaml config file and let it know about containerd 
      socket endpoint. Create file with below content at `/etc/crictl.yaml`
    
      ```yaml
      runtime-endpoint: unix:///var/run/containerd/containerd.sock
      image-endpoint: unix:///var/run/containerd/containerd.sock
      ```
    
      You can run commands like 
    
      ```sh
      sudo crictl pods
      sudo crictl images
      
      # list all containers
      sudo crictl ps -a
      
      # exec into a container
      sudo crictl exec "d79d833c711b8e342168a6ccb7f508a946503d014291fcce1eed15616a3d212d" /bin/sh -c "ps aux"
      
      # interactive exec
      sudo crictl exec -it "d79d833c711b8e342168a6ccb7f508a946503d014291fcce1eed15616a3d212d" /bin/sh
      
      # logs of a container
      sudo crictl logs "d79d833c711b8e342168a6ccb7f508a946503d014291fcce1eed15616a3d212d"
      ```

    * KubeletCTL
      
    
      Kubelet CTL is a tool that directly talks with kubelet and lets you know 
      information about that particular node on which that kubelet instance is 
      running
    
      ```sh
      KUBELETCTL_VERSION=v1.13
      ARCH=arm64
      
      curl -fsSLO "https://github.com/cyberark/kubeletctl/releases/download/${KUBELETCTL_VERSION?}/kubeletctl_linux_${ARCH?}"
      
      sudo install -m 755 kubeletctl_linux_${ARCH?} /usr/local/bin/kubeletctl
      ```
      
      with kubeletctl you can do the standard operations on a container running 
      on on node like 
      
      ```txt
      attach        Attach to a container
      checkpoint    Taking a container snapshot
      configz       Return kubelet's configuration.
      containerLogs Return container log
      cri           Run commands inside a container through the Container Runtime Interface (CRI)
      debug         Return debug information (pprof or flags)
      exec          Run commands inside a container
      healthz       Check the state of the node
      help          Help about any command
      log           Return the log from the node.
      metrics       Return resource usage metrics (such as container CPU, memory usage, etc.)
      pid2pod       That shows how Linux process IDs (PIDs) can be mapped to Kubernetes pod metadata
      pods          Get list of pods on the node
      portForward   Attach to a container
      run           Run commands inside a container
      runningpods   Returns all pods running on kubelet from looking at the container runtime cache.
      scan          Scans for nodes with opened kubelet API
      spec          Cached MachineInfo returned by cadvisor
      stats         Return statistical information for the resources in the node.
      version       Print the version of the kubeletctl
      ```
    
3. Control Plane Setup
  
  Control plane is the node from where all the decisions of what gets to run on 
  a cluster gets decided, this is where the brains and the memorystore of k8s
  resides. The components that run on a control plane node are as below
  
  * ETCD - Memory store in which all the information regarding a cluster is stored.
  ETCD is only ever accessed by the API-Server and all the other components get
  to know about cluster and its state from api-server and never really directly
  talk to a ETCD instance.
  
  * API-Server - The Server with which you talk to inorder to control a kubernetes
  cluster. This receives requests from clients (users, nodes in the cluster, cloud
  providers) and makes changes to the ETCD database to reflect the updated statuses
  after a change or responds to the request with the requested data.
  
  * Kube-Controller-Manager - The actual program which controls resources, makes sure
  they are made to be deployed when they are not present and removes them when not
  needed.
  
  * Kube-Scheduler - The program which keeps monitoring the workloads that are to be
  scheduled and also on the nodes and their statuses and decides which workload gets
  to live where in a given context.
  
  
  Lets start by installing things 1 by 1 on the control plane nodes
  
  * etcd
    
    Below is the script to install etcd
  
    ```sh
    #!/bin/bash
    
    ETCD_VERSION=v3.6.4
    ARCH=arm64
    
    curl -fsSLO "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION?}/etcd-${ETCD_VERSION?}-linux-${ARCH?}.tar.gz"
    
    tar xzvof "etcd-${ETCD_VERSION?}-linux-${ARCH?}.tar.gz"
    
    sudo install -m 755 "etcd-${ETCD_VERSION?}-linux-${ARCH?}"/{etcd,etcdctl,etcdutl} /usr/local/bin
    
    etcdctl completion bash | sudo tee /etc/bash_completion.d/etcdctl
    ```
    
    We will be running etcd with a different user, lets create a new use for that
  
    ```sh
    sudo adduser \
        --system \
        --group \
        --disabled-login \
        --disabled-password \
        --home /var/lib/etcd \
        etcd
    ```
  
    Now we create a systemctl script to enable start of etcd via systemd as a 
    unit service
    
    ```sh
    sudo wget -O /etc/systemd/system/etcd.service https://labs.iximiuz.com/content/files/courses/kubernetes-the-very-hard-way-0cbfd997/03-control-plane/01-etcd/__static__/etcd.service
    ```
    
  
  
4. Connectivity and configurations
