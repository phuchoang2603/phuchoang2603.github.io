---
title: How I Struggled (and Learned) to Deploy a Kubernetes Cluster on Proxmox with Terraform and Ansible
description:
date: 2025-05-15
tags:
  - self-hosted
  - devops
  - kubernetes
  - terraform
  - ansible
draft: false
featureimage: https://i.ibb.co/W418Zp9X/image.png
series:
  - Provision k8s on Proxmox
series_order: 1
---
Hi everyone! Have you ever tried using AWS, GCP, or Azure? It’s an amazing experience, right? The ability to spin up a couple of VMs, a Kubernetes (K8s) cluster, set up load balancers, high availability — all in just a few clicks. You can focus entirely on developing your product. I mean, yeah, why bother with the hassle of learning how all of that works under the hood?

Well... until the cost of cloud services hits you hard. If you just need to run small stuff, or deploy a simple demo web app for showcase purposes, no big deal — as long as you still have free credits from the cloud provider. But if you want to keep using those services, you either have to pay or keep creating fake emails or credit cards to hunt for whatever free credits are left.

Or... if you’re a student like me — someone who loves free stuff and enjoys recycling old electronics — why not set up your own cloud provider at home? It’s not as hard or expensive as you might think. You might only need one office desktop PC (i5 8th gen, Pentium, doesn’t really matter), and some RAM and storage. If you have even more? Why not try learning Kubernetes and set up your own cluster?

That’s the path I chose. Setting up Kubernetes sounded straightforward — but once I started reading, it became a confusing mess. There’s a lot of stuff to remember: master nodes, worker nodes, high availability, load balancers... And the setup requirements were not trivial. But since I had just learned **Ansible** and **Terraform** a few weeks ago, I decided:  **Why not make this a triple learning experience?**

And so, over the past couple of days, I dove deep into trying to set up my own **bare-metal Kubernetes cluster on Proxmox using Terraform and Ansible**. In this post, I want to share my experience — not as a fancy tutorial, but more like a overconfident student who struggled, googled like crazy, and finally made it work.

If you want the detailed documentation, check this instead:  

{{< github repo="phuchoang2603/kubernetes-proxmox" showThumbnail=true >}}

Demo video:

{{< youtubeLite id="Ao6IPSmUFcE" label="Video demo" >}}

---

## My Goal

- Use **Terraform** to create VMs on **Proxmox**.
- Bootstrap the **Kubernetes (RKE2)** cluster using **Ansible**.
- Use **Cloud-Init** to set up VMs properly.
- Make everything as clean and automated as possible (so I don't have to do it again manually).    

---
## Terraform Struggles: FML, I Didn’t Read the Docs
### 1. Figuring Out the Connection Between My Machine and Proxmox
Maybe it’s just me, but I found the [bpg/proxmox provider documentation](https://registry.terraform.io/providers/bpg/proxmox/latest/docs) incredibly detailed yet still confusing.  
First, I had to figure out how to create a `terraform` user and assign the appropriate role in Proxmox. Then, I needed to generate SSH keys, configure Proxmox to accept them, and figure out how to reference that private key correctly in my Terraform files.

On top of that, I needed to separate the SSH connection between the Proxmox API and the VMs themselves.  The SSH key I generated above was only for Terraform to manage Proxmox.  For the VMs (which are provisioned using Cloud-Init), I needed to inject a separate SSH key for Ansible and personal access.

### 2. Okay, Now I Can Connect. But How Do I Do the Magic?
Reading the docs felt all over the place. I ended up cloning the entire `bpg/proxmox` repo just to dig into the examples and understand how it works under the hood. I figured out how to download the Ubuntu cloud image directly onto Proxmox. Great, one task done.

But how do I spin up multiple VMs? I learned to create a **VM template** using the cloud image, configure the RAM, CPU, and network — so I could clone it later.

```yaml
resource "proxmox_virtual_environment_vm" "ubuntu_template" {
  name      = "ubuntu-template"
  node_name = "pve"

  template = true
  started  = false

  machine     = "q35"
  bios        = "ovmf"
  description = "Managed by Terraform"

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  efi_disk {
    datastore_id = "local"
    type         = "4m"
  }

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 20
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.user_data_cloud_config.id
  }

  network_device {
    bridge = "vmbr0"
  }

}

resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve"

  url = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}
```

### 3. Cloud-Init Snippets Were Tricky

After setting up the VM template, I thought spinning up multiple VMs using Cloud-Init would be easy with Terraform...Until it wasn’t.

I wanted each VM to have its own hostname (master-1, worker-1, etc.). Because if they don't, after deploying Ansible and ran `kubectl get nodes`, Kubernetes would only show one node. Turns out, they all had the same default hostname (`ubuntu`), so Kubernetes thought they were the same.

Also, I needed to configure qemu-guest-agent on all VMs so Terraform could detect their state (shutdown, power on, etc.). Without it, Terraform would just freeze and fail the task, even though the VMs were already created.

Fix? Use Cloud-Init snippets to set custom `qemu-guest-agent` and `local-hostname` properly for each nodes. Once I did that, all nodes showed up just fine and I can see the `qemu-guest-agent` on each nodes.

```yml
data "local_file" "ssh_public_key" {
  filename = "./id_rsa.pub"
}

resource "proxmox_virtual_environment_file" "user_data_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "pve"

  source_raw {
    data = <<-EOF
    #cloud-config
    hostname: test-ubuntu
    timezone: America/Toronto
    users:
      - default
      - name: ubuntu
        groups:
          - sudo
        shell: /bin/bash
        ssh_authorized_keys:
          - ${trimspace(data.local_file.ssh_public_key.content)}
        sudo: ALL=(ALL) NOPASSWD:ALL
    package_update: true
    packages:
      - qemu-guest-agent
      - net-tools
      - curl
    runcmd:
      - systemctl enable qemu-guest-agent
      - systemctl start qemu-guest-agent
      - echo "done" > /tmp/cloud-config.done
    EOF

    file_name = "user-data-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_file" "meta_data_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "pve"

  source_raw {
    data = <<-EOF
    #cloud-config
    local-hostname: test-ubuntu
    EOF

    file_name = "meta-data-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  # ...

  initialization {
    # ...
    user_data_file_id = proxmox_virtual_environment_file.user_data_cloud_config.id
    meta_data_file_id = proxmox_virtual_environment_file.meta_data_cloud_config.id
  }

  # ...
}
```

### 4. What’s the Right File Structure and Execution Order?

One thing that really tripped me up was **whether to keep everything in one big Terraform folder or split things into proper modules**. At first, I just dumped all the `.tf` files together, but it quickly became messy and hard to manage. After some thinking (and breaking things multiple times), I decided to **separate the VM template and the Kubernetes cluster into two clear modules**. To make things even smoother, I created a **Makefile that sources my `.env` variables automatically and handles `terraform init` and `apply` for each module**, so I don’t have to type long commands every time. This made my workflow much cleaner and less error-prone.

![](https://i.imgur.com/wg85qoC.png)

---
## Ansible: Why Bother?

That was my initial thought — why not just use Bash scripts?
But after watching videos from Jim’s Garage, I realized Ansible might actually make things cleaner, especially with its inventory and roles system.

https://www.youtube.com/watch?v=AnYmetq_Ekc&list=PLXHMZDvOn5sW-EXm2Ur5TroSatW-t0Vz_&index=11

### 1. Choosing which method to follow
Initially, I didn’t try the RKE2 script from Jim's Garage because I saw a lot of issues reported on his GitHub repo. So, I switched to Techno Tim’s script (K3s version). But I immediately saw red flags with this project as I encountered an issue where the installation froze and eventually failed, becoming unexecutable afterward.

![](https://i.imgur.com/S3NTRpp.png)

I even SSHed into the master nodes to check the logs, but honestly, I couldn’t understand much of it (lmao). I tried to look through his GitHub issues, but it turned out most of the older issues were automatically moved to the discussions section and closed without any replies or troubleshooting provided.

![](https://i.imgur.com/86x5ej9.png)

To be clear, I’m not trying to speak negatively about his project (it’s open-source, free, and a great effort, by the way). I did try to dive deeper and fix the bugs myself, but it was too complex. So, I ended up going back to the Jim's Garage script.

### 2. Initial Success, but Needed Some Modifications
It was definitely a smoother experience diving into Jim's Garage script, but there were still a lot of hard-coded values and links that I needed to adjust.

First, the script didn’t support a dynamic number of master nodes — it only worked with exactly three nodes. So, I had to modify the rke2-prepare and add-server roles to work with just two nodes, which is what I’m using.

Second, the script had a hardcoded URL when applying the L2Advertisement manifest, which caused a 502 Bad Gateway error. I had to download the file, make it a local template, and reference it locally.

Lastly, I had to correct the MetalLB load balancer IP range (this was my fault for forgetting basic networking lessons 😅). I had mistakenly set an IP range that exceeded 255, so I fixed it by changing the range back to 230-250.

![](https://i.imgur.com/sMraf2I.png)


### 3. Python Scripts to Save My Sanity

I also got tired of updating the `hosts.ini` and `group_vars` manually.  
So, I wrote **Python scripts to auto-generate them from my `k8s_nodes.json` and `.env` files**.

Now I can just update the JSON, run the script, and my Ansible files are updated.

![](https://i.imgur.com/x9X4hW6.png)

---

##  Final Thoughts

This project wasn’t just about spinning up a Kubernetes cluster —  
It taught me about **the importance of automation, details, timing, and clean workflows**.

I made a lot of mistakes along the way, but now I have a fully automated setup that I can reuse anytime.

It felt like a long journey, but I’m glad I kept pushing through.  
Next time, I’ll remember:

> "**The magic is in the small details.**"