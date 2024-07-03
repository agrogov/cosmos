# k8s cluster from the scratch with autodeployment

Task:

- Automate the deployment of a local kubernetes cluster
- Automate the deployment of a testnet cosmos rpc node
- Automate the deployment of grafana and prometheus to view the resources used such as cpu / memory / disk space etc..

## Prerequesites

- Terraform >= 1.9
- Two VMs with [Ubuntu 24.04 Live Server](https://releases.ubuntu.com/noble/ubuntu-24.04-live-server-amd64.iso) installed
  - k8s master: 2 vCPU, 4Gi RAM, network bridget to your local net
  - k8s worker: 4 vCPU, 16Gi RAM, network bridget to your local net

## Configuration

- On both VMs should be:
  - OpenSSH server enabled
  - Public key installed
    ```bash
      $ ssh-copy-id -i ~/.ssh/id_rsa.pub ubuntu@192.168.31.72
    ```
  - Password disabled for sudo user `ubuntu`
    ```bash
      $ sudo visudo
      # add line at the bottom of the file
      ubuntu  ALL=(ALL) NOPASSWD:ALL
    ```
- Set master/worker IPs and private key path in `terraform/terraform.tfvars` file:
  ```bash
  master_ip       = "192.168.31.72"
  worker_ips      = ["192.168.31.127"]
  ssh_user        = "ubuntu"
  ssh_private_key = "~/.ssh/id_rsa"
  kubeconfig      = "/tmp/kubeconfig/admin.conf"
  ```
- In `terraform/metallb/address-pool.yaml` set one free IP address from your local network:
  ```yaml
  spec:
  addresses:
    - 192.168.31.253/32
  ```

## Applying Terraform

```bash
$ terraform init
$ terraform apply -target=module.k8s_cluster -auto-approve
$ terraform apply -target=module.cert_manager -auto-approve
$ terraform apply -auto-approve
```

## Access k8s cluster

Admin kubeconfig could be found in `/tmp/kubeconfig/admin.conf` on your machine after k8s cluster deployment complete.
Or just use `kubectl` on master/worker VM.

## Access Grafana dashboard

Use IP address you set in `terraform/metallb/address-pool.yaml` to access http://192.168.31.253:3000/

Credetials:

Login: admin

Password:

```bash
$ kubectl get secret grafana-admin --namespace monitoring -o jsonpath="{.data.GF_SECURITY_ADMIN_PASSWORD}" --kubeconfig /tmp/kubeconfig/admin.conf | base64 -d
```
