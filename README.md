# Kubernetes - The Hard Way

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
3. Control Plane Setup
4. Connectivity and configurations
