resource "null_resource" "k8s_init" {
  for_each = toset(concat([var.master_ip], tolist(var.worker_ips)))

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y docker.io",
      "sudo apt-get install -y apt-transport-https ca-certificates curl gpg",
      "sudo mkdir -p -m 755 /etc/apt/keyrings",
      "sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg && curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg",
      "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update -y",
      "sudo apt-get install -y kubelet kubeadm kubectl",
      "sudo apt-mark hold kubelet kubeadm kubectl",
      "sudo sed -i '/swap/ s/^/#/' /etc/fstab",
      "sudo swapoff -av",
      <<-EOF
      cat <<EOF2 | sudo tee /etc/sysctl.d/k8s.conf
      net.ipv4.ip_forward = 1
      EOF2
      EOF
      ,
      "sudo sysctl --system",
      "sudo mkdir -p /etc/containerd/ && containerd config default | sudo tee /etc/containerd/config.toml",
      "sudo sed -i 's/SystemdCgroup \\= false/SystemdCgroup \\= true/g' /etc/containerd/config.toml",
      "sudo sed -i 's/\\(sandbox_image = \"registry.k8s.io\\/pause:\\)[^\"]*\"/\\13.9\"/' /etc/containerd/config.toml",
      "sudo systemctl restart containerd.service",
      "sudo systemctl stop apparmor && sudo systemctl disable apparmor && sudo apt purge apparmor -y",
      "mkdir -p -m 755 /home/${var.ssh_user}/.kube",
      "sudo reboot"
    ]

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_private_key)
      host        = each.value
    }
  }
}

resource "null_resource" "k8s_master" {
  depends_on = [null_resource.k8s_init]

  provisioner "file" {
    source      = "${path.module}/calico.yaml"
    destination = "/home/${var.ssh_user}/calico.yaml"
    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_private_key)
      host        = var.master_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl enable --now kubelet",
      "sudo kubeadm init --pod-network-cidr=10.255.0.0/16 --control-plane-endpoint=${var.master_ip} --cri-socket=unix:///run/containerd/containerd.sock",
      "sudo cp -f /etc/kubernetes/admin.conf /home/${var.ssh_user}/.kube/config",
      "sudo chown ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/.kube/config",
      "kubectl apply -f /home/${var.ssh_user}/calico.yaml",
      "kubectl rollout status deployment/calico-kube-controllers -n kube-system",
      "kubectl rollout status daemonset/calico-node -n kube-system"
    ]

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_private_key)
      host        = var.master_ip
    }
  }
}

resource "null_resource" "copy_kubeconfig" {
  depends_on = [null_resource.k8s_master]

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p /tmp/kubeconfig
      ssh -i ${var.ssh_private_key} -o StrictHostKeyChecking=no ubuntu@${var.master_ip} "sudo cat /etc/kubernetes/admin.conf" > ${var.kubeconfig}
    EOT
  }
}

resource "null_resource" "join_worker" {
  for_each = toset(var.worker_ips)

  depends_on = [null_resource.k8s_init, null_resource.k8s_master, null_resource.copy_kubeconfig]

  provisioner "file" {
    source      = var.ssh_private_key
    destination = "/home/${var.ssh_user}/.ssh/id_rsa"
    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_private_key)
      host        = each.value
    }
  }

  provisioner "file" {
    source      = var.kubeconfig
    destination = "/home/${var.ssh_user}/.kube/config"
    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_private_key)
      host        = each.value
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/ubuntu/.ssh/id_rsa",
      "JOIN_CMD=$(ssh -o StrictHostKeyChecking=no ${var.ssh_user}@${var.master_ip} kubeadm token create --print-join-command)",
      "ssh -o StrictHostKeyChecking=no ${var.ssh_user}@${each.value} sudo $JOIN_CMD",
      "kubectl label node $(hostname -s) node-role.kubernetes.io/worker=worker"
    ]

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_private_key)
      host        = each.value
    }
  }
}
