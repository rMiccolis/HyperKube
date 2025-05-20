# 🌐 Networking & DNS Setup

HyperKube creates a simulated private cloud-like network for all VMs using the following technologies:

---

## 🔗 WireGuard VPN

- Secure peer-to-peer VPN connection between all VMs
- Allows communication between machines on different networks (ex: master on LAN, workers on a VM bridge)
- QR code output makes it easy to join mobile or remote nodes
- Is possible to setup the kubernetes cluster upon its interfacewith http protocol instead of public IP and https

---

## 📛 BIND9 DNS Server

A **BIND9 DNS server** is installed and configured on the master VM.

- Resolves internal hostnames for all nodes in the cluster
- Works like a VPC DNS resolver in cloud setups
- Ensures that Kubernetes nodes and deployed apps can reach each other by name
- Useful just in case the cluster runs on the Wireguard VPN interface

---

## 🔐 Required Open Ports

| Port   | Purpose                     |
|--------|-----------------------------|
| 51820  | WireGuard VPN               |
| 27017  | MongoDB access              |
| 443    | HTTPS for secure web apps   |
| 80     | Let's Encrypt certificate issuance (can close after setup) |

---

## 🌍 IP & MAC Binding

To maintain consistent networking:

**Set static IPs for each VM on your router**, using MAC address mapping
  Ex:

- MAC_ADDRESS: 00:15:5D:38:01:30 → IP: 192.168.1.200 (master)
- MAC_ADDRESS: 00:15:5D:38:01:31 → IP: 192.168.1.201 (worker1)
