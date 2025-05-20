# 🚀 HyperKube

## 💡 Project Description: AWS Production Environment Simulator

This project provides a **powerful** and **flexible** solution for simulating a production-like cloud environment directly on a Windows operating system using Hyper-V virtualization. Instead of relying on actual AWS services, it uses some custom automation scripts to provision and configure a fully functional, bare-metal infrastructure.

At its core, the project automates the creation of Ubuntu virtual machines with user-defined specifications. Leveraging `cloud-init`, these VMs are initialized with essential configurations, paving the way for a comprehensive ecosystem of production-grade tools.

The automation extends to the deployment and configuration of critical network and application infrastructure components, including:

- **💻 BIND9 DNS Server:** For internal domain name resolution within the environment.
- **🛡️ Wireguard VPN:** Providing secure and private network connectivity to the infrastructure.
- **🐳 Docker and Kubernetes:** The foundation for containerized application deployment and orchestration.
- **🌐 Calico:** As the Container Network Interface (CNI) for Kubernetes networking.
- **⚖️ MetalLB:** Enabling bare-metal load balancing, providing stable IP addresses for services.
- **📦 Helm:** A Kubernetes package manager for simplifying the installation and management of applications.
- **🚦 Nginx Ingress Controller:** Managing external access to applications running within the Kubernetes cluster.
- **🔒 cert-manager:** Automating the acquisition and renewal of Let's Encrypt SSL certificates for secure HTTPS connections.
- **💾 MongoDB:** An optional MongoDB instance ready to be used by other apps. See [main_config_example](https://github.com/rMiccolis/HyperKube/blob/master/doc/main_config_example.yaml) for info on how to deploy it.

Furthermore, the project facilitates the deployment of user-defined applications by cloning project repositories and installing them onto the Kubernetes cluster based on provided YAML configurations. It even supports variable substitution within these configuration files, allowing for environment-specific settings.

**In essence, this project offers a self-contained, customizable, and cost-effective way to:**

- **Learn and experiment** with cloud-native technologies like Kubernetes, Docker, and associated ecosystem tools in a realistic environment.
- **🧪 Develop and test applications** in a simulated production setting before deploying to actual cloud providers.
- **⚙️ Understand the underlying infrastructure** and configurations required for a cloud-based application deployment.
- **Create isolated and reproducible environments** for development, testing, or demonstration purposes.

By abstracting away the complexities of manual setup and configuration, the project empowers users to quickly spin up and manage a sophisticated simulated production environment, fostering learning, experimentation, and efficient application development workflows.

---

There are 4 main scripts that create and configure all the infrastructure and need a configuration yaml file (`main_config.yaml`) to be executed (an example is found at [main_config_example](https://github.com/rMiccolis/HyperKube/blob/master/doc/main_config_example.yaml)).

**📜 Script Description:**

- **💻 `infrastructure/windows/generate_hyperv_vms.ps1`:** This script manages the generation and configuration of Ubuntu virtual machines. It utilizes `cloud-init` to provide the initial configuration to VMs. At the end of the script, it opens a `cmd` instance and copies to the clipboard the command to be pasted in to start the `start.sh` script.
- **🚀 `infrastructure/start.sh`:** This script is executed on the main VM and performs all the tasks to create a Kubernetes cluster and install the client-server application on it.
- **➕ `bin/setup_worker_nodes.sh`:** This script is useful for joining a new node to the cluster (control plane or worker) and configuring it (install Docker, Kubernetes, etc.).
- **🔗 `bin/add_wireguard_peer.sh`:** Run this script to generate a Wireguard peer configuration. It prints out the QR code to be scanned by Android or iOS apps to join the VPN.

## 📚 FOR USAGE INSTRUCTIONS REFER TO

[Instructions for infrastructure startup and parameter setttings](https://github.com/rMiccolis/HyperKube/blob/master/doc/usage.md)

---

## License

This project is released under the [GNU General Public License v3](https://www.gnu.org/licenses/gpl-3.0.html).

See the [LICENSE](https://github.com/rMiccolis/HyperKube/blob/master/COPYING) file for complete details.
