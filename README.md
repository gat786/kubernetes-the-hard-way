# Kubernetes - The Hard Way

I am gonna be using the course by Márk Sági-Kazár on Iximiuz Labs
called Kubernetes The Very Hard way as my guiding point, which in turn
is based out of Kelsey Hightowers Kubernetes the Hard Way repository.

Inorder to make the networking work across vms, I had to change networking
type of vms to be `user-v2` in the networks.

Doing this makes the vms accessible to each other at `lima-INSTANCE_NAME.internal`
this makes it possible for us to make the cross vm communication work.
The connectivity from hosts to vms is done a little differently.

Inorder to make sure that our host system is able to communicate with vms,
we will have to open up a socks proxy tunnel using limactl and then use
the tunnel as proxy argument in curl to be able to reach pods.

```
$ limactl tunnel worker
WARN[0000] `limactl tunnel` is experimental
Open <System Settings> → <Network> → <Wi-Fi> (or whatever) → <Details> → <Proxies> → <SOCKS proxy>,
and specify the following configuration:
- Server: 127.0.0.1
- Port: 56827
The instance can be connected from the host as <http://lima-worker.internal> via a web browser.
```

```
$ curl -k --proxy socks5h://127.0.0.1:56827 https://lima-worker.internal:10250/pods
```

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
    
    Since etcd is a critical part if a Kubernetes installation and it is also 
    the only part which actually writes files to the disk and needs access to a
    directory to read and write files, we ought to take special considerations
    when deploying it, we will be running etcd with a different user, 
    lets create a new use for that
  
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
    sudo wget -O /etc/systemd/system/etcd.service \
        https://labs.iximiuz.com/content/files/courses/kubernetes-the-very-hard-way-0cbfd997/03-control-plane/01-etcd/__static__/etcd.service
    ```
  
    Interacting with etcd can be done using etcdctl and it comes along with an etcd
    installation, we just did it and we should already have it in our machine.
  
    We can use commands like this 
  
    ```
    etcdctl endpoints health
  
    # insert data
    etcdctl put foo foovalue
    
    # get present data
    etcdctl get foo
    
    # the above will return value and key, inorder to only values
    etcdctl get foo --print-value-only
  
    # data can also be inserted in a prefix-based fashion
    etcdctl put /foo/key value
  
    # keys can be listed like below
    etcdctl get --prefix /foo --keys-only
    ```
  
    This is the part where we begin to add components to the system and there 
    needs to be some common best practices that we should follow inorder to make
    sure that the flow of communication of data across our cluster remains fast
    and secure all throughout. It basically means we dont want to egress of ingress
    any traffic which is not secure or encrypted by default. Doing that would lead
    to easy manipulation of data that can result in harmful consequences.
  
    We want to start utilising TLS certificates to encrypt our data in air and 
    make sure it is unreadable to anyone who catches it in-transit.
    
    Lets start with setting it up for etcd.
    
    Create a directory to hold PKI Data
  
    ```sh
    sudo mkdir -p /etc/etcd/pki
    cd /etc/etcd/pki
    ```
  
    Lets create a certificate authority with which we can create certificates 
    for different components
  
    ```sh
    sudo openssl genrsa -out ca.key 4096
    
    sudo openssl req -x509 -new -noenc \ #ktvhw uses nodes which is no-des encryption, this flag has been deprecated.
        -key ca.key -out ca.crt \
        -subj "/CN=etcd" \
        -sha256 \
        -days 3650
    ```
  
    Inorder for a etcd setup to work, we need multiple certs, 
    1. etcd-server certificate, something which server will have in its process
        using which it will identity itself as the etcd server.
    2. etcd-client certificate, something which the clients that connect with etcd
        will present whenever they raise a req to the etcd process.
    
    They can be created as below, starting with server cert
    
    ```sh
    cat <<EOF | sudo tee server.cnf
    [ req ]
    default_bits       = 2048
    distinguished_name = req_distinguished_name
    req_extensions     = req_ext
    prompt             = no
    
    [ req_distinguished_name ]
    CN = server
    
    [ req_ext ]
    subjectAltName = @alt_names
    
    [ alt_names ]
    DNS.1 = localhost
    DNS.2 = $(hostname)
    IP.1  = 127.0.0.1
    IP.2  = ::1
    IP.3 = $(ip -o -4 addr show | grep 'eth' | awk '{split($4,a,"/"); print a[1]}' | paste -sd,)
    EOF
    
    sudo openssl genrsa -out server.key 2048
    sudo openssl req -new -key server.key -out server.csr -config server.cnf
    sudo openssl x509 -req -in server.csr -out server.crt \
      -CA ca.crt -CAkey ca.key \
      -days 365 -extfile server.cnf -extensions req_ext

    ```
    
    and the client cert
    
    ```sh
    sudo openssl genrsa -out client.key 2048
    sudo openssl req -new -key client.key -out client.csr -subj "/CN=etcd/O=etcd"
    sudo openssl x509 -req -in client.csr -out client.crt \
      -CA ca.crt -CAkey ca.key \
      -days 365
    ```
    
    Since we are running etcd from a different linux user and group, lets
    change the ownership of the pki directory to make sure that only etcd user and 
    group own that directory and can read and write to that directory.
  
    ```sh
    sudo chown -R etcd:etcd .
    ```
    
    We also want to make sure that the client.key is accessible to everyone 
    (every possible client, in our case it will only be kube-apiserver)
  
    ```sh
    sudo chmod 644 client.key
    ```
  
    We want to configure the etcd-server to use the certificates that we just 
    created
    
    ```sh
    cat <<EOF | sudo tee -a /etc/default/etcd
    
    ETCD_LISTEN_CLIENT_URLS=https://0.0.0.0:2379
    
    ETCD_CLIENT_CERT_AUTH=true
    ETCD_CERT_FILE=/etc/etcd/pki/server.crt
    ETCD_KEY_FILE=/etc/etcd/pki/server.key
    ETCD_TRUSTED_CA_FILE=/etc/etcd/pki/ca.crt
    
    ETCD_NAME=$(hostname)
    ETCD_ADVERTISE_CLIENT_URLS=https://$(hostname):2379
    
    EOF
    
    sudo systemctl restart etcd
    ```
  
    We want to now configure the etcdctl client to use the certificates
  
    ```sh
    cat <<EOF | tee -a "$HOME/.bashrc" "$HOME/.profile"
    
    export ETCDCTL_CACERT=/etc/etcd/pki/ca.crt
    export ETCDCTL_CERT=/etc/etcd/pki/client.crt
    export ETCDCTL_KEY=/etc/etcd/pki/client.key
    export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
    EOF
    
    # we check if its working or not
    bash --login -c "etcdctl endpoint health"
    ```
  
  * kube-apiserver
    
    Kube-ApiServer is the frontend of kubernetes, inorder to deploy an app or
    inorder to expose a service basically whatever changes you would want to make
    to a kubernetes cluster they go through Kube-ApiServer.
    
    This is where we start to get in holy grails of Kubernetes
  
    ```sh
    KUBE_VERSION=v1.34.0
    
    curl -fsSLO "https://dl.k8s.io/${KUBE_VERSION?}/bin/linux/amd64/kube-apiserver"
    
    sudo install -m 755 kube-apiserver /usr/local/bin
    ```
    
    Getting the service file and then storing it in the systemd directory, so 
    that we can start it up using systemctl commandline app
  
    ```sh
    sudo wget -O /etc/systemd/system/kube-apiserver.service \
        https://labs.iximiuz.com/content/files/courses/kubernetes-the-very-hard-way-0cbfd997/03-control-plane/02-kube-apiserver/__static__/kube-apiserver.service?v=1774217654
    ```
  
    Kube API Server also requires PKI items
  
    ```sh
    sudo mkdir -p /etc/kubernetes/pki
    cd /etc/kubernetes/pki
    ```
  
    ```sh
    (
        sudo mkdir -p /etc/kubernetes/pki
        cd /etc/kubernetes/pki
        sudo openssl genrsa -out sa.key 2048
        sudo openssl rsa -in sa.key -pubout -out sa.pub
    )
    ```
  
  
  
4. Connectivity and configurations
