---
title: Automate provisioning Kubernetes cluster on Proxmox with Terraform + Ansible
description:
date: 2025-05-31
tags:
  - devops
  - kubernetes
  - proxmox
draft: false
layout: "zen"
featureimage: https://i.ibb.co/W418Zp9X/image.png
---

This project automates the provisioning and configuration of a RKE2 Kubernetes on **Proxmox** using **Terraform** and **Ansible**, with following features:

- `AWS S3` for `Terraform` remote state
- Separate `dev` and `prod` environment variables
- Multiple nodes `Proxmox` cluster

- `kube-vip` for high availability virtual IP
- SSL via `cert-manager` with `Cloudflare` DNS
- `Longhorn` for persistent storage
- `ArgoCD` for GitOps deployment

{{< github repo="phuchoang2603/kubernetes-proxmox" showThumbnail=true >}}

{{< article link="/posts/terraform-ansible-proxmox-k8s" showSummary=true compactSummary=true >}}

Video demo:

{{< youtubeLite id="Ao6IPSmUFcE" label="Video demo" >}}

---

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/phuchoang2603/kubernetes-proxmox
cd kubernetes-proxmox
```

### 2. Set Up Environment Variables for Terraform

```bash
cp .env.example .env
```

Then edit .env to reflect your Proxmox IP, credentials, Cloudflare token, etc. You also need to customize your hostnames and IPs in `config/k8s_nodes.json` and `config/longhorn_nodes.json`.

If you want to use S3 for Terraform state, set the relevant variables in `config/dev.s3.tfbackend` as well.

### 3. Set Up Ansible

You need to have your ssh public key in the `keys/` directory for Ansible to use for SSH access to the nodes. You might also want to use uv to manage the Python virtual environment. If not, simply ensure you have Ansible and the required collections installed in your Python environment.

```bash
cp ~/.ssh/id_ed25519.pub keys/
uv venv
source .venv/bin/activate
uv sync
```

### 4. Run the Master Script

```bash
cd scripts
./master.sh

# If you want to skip Longhorn, SSL, or kube-vip setup, you can use the flags:
./master.sh --skip-longhorn --skip-ssl --skip-kube_vip
```

---

## What the Master Script Does

The `master.sh` script orchestrates everything:

### Phase 1: Terraform – Provisioning

- Configure backend state to use Amazon S3 or not
- Downloads the base cloud-init image
- Provisions Kubernetes and (optionally) Longhorn VMs on Proxmox

### Phase 2: Ansible – Cluster Bootstrap

- Installs RKE2 (Kubernetes)
- Configures kube-vip, Longhorn, and cert-manager + Cloudflare if enabled

---

## Credits

- Inspired by [JimsGarage RKE2 Ansible Playbooks](https://github.com/JamesTurland/JimsGarage)
- Built with [bpg Proxmox Terraform Provider](https://registry.terraform.io/providers/bpg/proxmox/latest)