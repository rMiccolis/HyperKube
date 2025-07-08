## 🛠️ INSTRUCTIONS TO RUN THE INFRASTRUCTURE SETUP

## ⚙️Virtual machine operations

### ✅ tested versions

- Ubuntu version: Ubuntu Server 24.04 LTS (Noble Numbat) (QCow2 UEFI/GPT Bootable disk image)
- Kernel version: Linux 6.8.0-57-generic
- Docker version: 28.0.4, build b8034c0 (scritps always try to install latest version)
- Cri-dockerd version: 0.3.17 (scritps always try to install latest version)
- Kubernetes version: v1.32.3 (scritps always try to install latest version)

⚠️ After creating VM with a linux distro:
(Skip these steps if launching infrastructure from "generate_hyperv_vms.ps1")

- Disable windows secure boot
- Set minimum 50GB of disk space
- Set at least 2 cpus
- Set at least 4096MB of RAM

## Mandatory OS Operations before executing './infrastructure/start.sh' (follow these steps in the example paragraph)

- **🐧 Create a virtual switch on Hyper-V with name: "VM"**
- **🐧 Choose a linux distro which makes use of systemd as init service**
- **💻 Set static MAC address and assign a fixed ip address to it from the router** (EX: MAC address: 00 15 5D 38 01 30 and assign it to ip address 192.168.1.200. MAC address list => 00 15 5D 38 01 30, 00 15 5D 38 01 31, 00 15 5D 38 01 32...)
- **🌐 If you don't have a static public IP, you need to setup NO-IP DDNS service in order to make wireguard work.**
- **🔑 Install an ssh server** (Skip this step if launching infrastructure from "generate_hyperv_vms.ps1")
- **🤝 Add all cluster partecipating hosts to the hosts file**
- **🔒 Copy ssh public key into .ssh authorized_keys file of the remote host to use ssh connection without password prompt** (Skip this step if launching infrastructure from "generate_hyperv_vms.ps1")
- **🛡️ Enable passwordless sudo to the system user account to which connect through ssh (in sudoers file append using sudo visudo: $USER ALL=(ALL) NOPASSWD: ALL) [Where $USER is your username on your system ]** (Skip this step if launching infrastructure from "generate_hyperv_vms.ps1")
- Open 51820 port (the Wireguard VPN port) on the modem/router to let application and mongodb database to be reachable (if VPN is selected).
- Open 27017 port (the default MongoDB port) on the modem/router to let application and mongodb database to be reachable.
- Open 443 port on the modem/router to let application be reachable with SSL encryption and have a secure connection over HTTPS.
- Open 80 port on the modem/router to let script automatically obtain a Let's Encrypy SSL certificate to be used for HTTPS connection (it can be turned off after script ends).
- 🔑 Create a [docker access token](https://docs.docker.com/docker-hub/access-tokens/) (to be provided into main_config.yaml)

## Launch script for auto creating VM on hyper-v (windows) and setup and boot all the application

### The script makes use of cloud-init to give a starting linux configuration (ssh server, ssh key-pairs, remove psw to execute sudo commands, loads main_config.yaml and pulls the github repo)

**IMPORTANT:**
TO LET THIS SCRIPT WORK, YOU **MUST**:

- Download ADK - https://learn.microsoft.com/it-it/windows-hardware/get-started/adk-install. You only need to install the deployment tools once in the default location. Oscdimg is used to write the CIDATA image (containing meta-data and user-data files) for cloud init as a ISO 9660 image
- Download qemu-img: http://www.cloudbase.it/qemu-img-windows/. Quemu is used to convert ubuntu cloud-image to a virtual hard drive to be used by virtual machines
- **PICK A CLOUD-IMAGE ISO FOR YOUR LINUX DISTRO (ex: [focal-server-cloudimg-amd64 download link](https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img) )**
- have the ssh key pairs of the host you're launching all the infrastructure from (used to access and setup all other hosts. The host is your host that has access to github repo and from which the script will be launched) at the default path C:\Users\USERNAME\\.ssh\ . This key must have access to github repository

### Launch generate_hyperv_vms.ps1:

Input parameters:

- [`main_config_file_path`](https://github.com/rMiccolis/HyperKube/blob/master/doc/main_config_example.yaml) **(mandatory)** => This is the path to the configuration file and MUST be called "main_config.yaml". This is the yaml file to configure virtual machines and application.
- [`apps_config_file_path`](https://github.com/rMiccolis/HyperKube/blob/master/doc/apps_config.yaml) ([instructions](https://github.com/rMiccolis/HyperKube/blob/master/doc/app_config_instructions.md)) => This is the path to the configuration file and MUST be called "apps_config.yaml". This is the yaml file where to store variables to be substituted inside projects (kubernetes folder) yaml configuration files. Remember to use a name convention for yaml files inside root_project/kubernetes letting them start with an incremental id number (so they are executed with a order).
- `mongodb_values_file_path` (optional) => This is the path to a mongodb_values.yaml configuration file for mongodb bitnami helm chart and MUST be called "mongodb_values.yaml". For usage see [MongoDB installation](#mongodb-installation) This is the yaml file to configure the chart. For info on how to fill this file see the [Bitnami Helm chart](https://artifacthub.io/packages/helm/bitnami/mongodb). It must be provided if you want to use a custom values.yaml file to be provided to the Bitnami Helm chart.
- `mongodb_setup_file_path` (optional) => This is the path to a bash file that is executed right BEFORE the start of bitnami mongodb install. In this file you are able to perform all the actions needed to get the cluster (or the master VM) ready for bitnami mongodb helm install.

## MongoDB installation

There are two methods to install it:

1. With the default configuration (you are free to skip "mongodb_values_file_path" parameter):

   ```yaml
   architecture: standalone
   tls:
   enabled: true
   existingSecret: mongodb-ca-secret
   extraDnsNames:
   - "$load_balancer_dns_name"
   auth:
   enabled: true
   rootUser: $mongo_root_username
   rootPassword: $mongo_root_password
   persistence:
   enabled: true
   existingClaim: mongodb-pvc
   securityContext:
   runAsUser: 1001
   runAsGroup: 1001
   fsGroup: 1001
   volumePermissions:
   enabled: true
   ```

   Where "$load_balancer_dns_name", "$mongo_root_username" and "$mongo_root_password" have to be provided inside main_config.yaml.
   With this method you don't have to provide any file as parameter to generate_hyperv_vms.ps1, just fill those variables inside the main_config.yaml.
   Example:

   ```yaml
   install_mongodb: "true"
   ```

2. With a custom mongodb_values.yaml

   - Provide inside main_config.yaml just the following:

   ```yaml
   install_mongodb: "true"
   ```

   - Provide mongodb_values.yaml to generate_hyperv_vms.ps1 with the parameter "-mongodb_values_file_path" with the path to the file:

   ```powershell
   powershell.exe -noprofile -executionpolicy bypass -file "E:\path\to\generate_hyperv_vms.ps1" -main_config_file_path "E:\\path\to\main_config.yaml" -apps_config_file_path "E:\\path\to\apps_config.yaml" -mongodb_values_file_path "E:\\path\to\mongodb_values.yaml"
   ```

   You can get info on how to configure this file at the [Bitnami helm chart](https://artifacthub.io/packages/helm/bitnami/mongodb)

   - if you have to perform additional setup to make the configuration work, provide a file named "mongodb_setup.sh" to this script with the parameter "-mongodb_setup_file_path" which will skip the application of files inside ./kubernetes/mongodb/ folder. Provide inside main_config.yaml the following:

     ```yaml
     install_mongodb: "true"
     ```

     After "mongodb_setup.sh" execution, the process will install mongodb bitnami helm chart with "mongodb_values.yaml" file configuration at "/home/$USER/mongodb_values.yaml"

   Example of script execution:

   ```powershell
   powershell.exe -noprofile -executionpolicy bypass -file "E:\path\to\generate_hyperv_vms.ps1" -main_config_file_path "E:\\path\to\main_config.yaml" -apps_config_file_path "E:\\path\to\apps_config.yaml" -mongodb_values_file_path "E:\\path\to\mongodb_values.yaml" -mongodb_setup_file_path "E:\\path\to\mongodb_setup.sh"
   ```

### MongoDB tls connection

The tls certificate to connecto to Mongodb will be found at /home/$USER/tls/tls-cert.pem. Provide this certificate to your connection string.

To use this certificate you can copy the tls-cert.pem inside the application docker image. This can be achieved submitting the a bash (.sh) file with the property "exec_script_before_deploy" inside the [apps_config_file_path](https://github.com/rMiccolis/HyperKube/blob/master/doc/app_config_instructions.md). EX:

```bash
# copy the tls file from $repository_root_dir/
cp "/home/$USER/tls/tls-cert.pem" "/home/$USER/apps/YOUR_APPLICATION_NAME/mongodb-tls-cert.pem"
# Start building YOUR_APPLICATION_NAME docker image
sudo docker build -t $docker_username/YOUR_IMAGE_NAME -f /home/$USER/apps/YOUR_APPLICATION_NAME/YOUR_APPLICATION_NAME.dockerfile /home/$USER/apps/YOUR_APPLICATION_NAME/
```

Then you can see it inside your application and find it according to the position you provided inside your docker image

Nodejs options example with mongoose:

```javascript
const serverRoot = __dirname;
const pem_file_path = path.join(serverRoot, "mongodb-tls-cert.pem");
mongodb_options = {
  tls: true,
  tlsCAFile: pem_file_path,
  tlsCertificateKeyFile: pem_file_path,
};
```

## Your Custom Applications install

In your project you have to provide a "kubernetes" folder with all the .yaml files needed to install the application.
In addition you can have:

- env_substitution folder: here you can place all the files containing variables to be substituted (in the form of ${var} or $var). See [Environment Variables usable inside exec_script_before_deploy or exec_script_after_deploy and env_subsitution folder](https://github.com/rMiccolis/HyperKube/blob/master/doc/app_config_instructions.md#environment-variables-usable-inside-exec_script_before_deploy-or-exec_script_after_deploy-and-env_subsitution-folder)
- "bin" folder: here you can have 2 .sh files, one for preparing deploy (edit .yaml files or create secrets or other resources) that is executed before applying kubernetes' folder files and one executed after this.

```powershell
powershell.exe -noprofile -executionpolicy bypass -file "E:\Desktop\HyperKube\infrastructure\windows\generate_hyperv_vms.ps1" -main_config_file_path "E:\Download\main_config.yaml" -apps_config_file_path "E:\Download\apps_config.yaml"
```

---

## MANUAL STARTUP EXAMPLE (NOT RECOMMENDED!)

**EXECUTE THESE INSTRUCTIONS on host with github cloning permissions! ('m1' is the host that will have the master role inside the cluster)**
**('w1' is the host that will have the worker role inside the cluster, the others will be w2,w3 and so on)**

**Copy your ssh public key into .ssh authorized file of the remote host to use ssh connection without password prompt (## to be done for all hosts):**

```bash
scp C:\Users\ROB\.ssh\id_rsa.pub m1@m1:/home/m1/.ssh/authorized_keys
scp C:\Users\ROB\.ssh\id_rsa.pub w1@w1:/home/w1/.ssh/authorized_keys
```

**Create master and workers ssh key pairs (## to be done for all hosts):**

```bash
ssh m1@m1 "ssh-keygen -q -N '' -f ~/.ssh/id_rsa <<<y >/dev/null 2>&1"
ssh w1@w1 "ssh-keygen -q -N '' -f ~/.ssh/id_rsa <<<y >/dev/null 2>&1"
```

**Download master's public key:**

```bash
scp m1@m1:/home/m1/.ssh/id_rsa.pub E:\Download\
```

**Insert master's public key into workers' authorized_keys file (to be done for all workers):**

```bash
scp E:\Download\id_rsa.pub w1@w1:/home/w1/.ssh/authorized_keys
```

**Clone the repo into master remote host:**

```bash
scp -r -q E:\Desktop\HyperKube m1@m1:/home/m1/
ssh m1@m1 "chmod -R u+x ./HyperKube"
```

**Copy main_config.yaml to master remote host to for application configuration:**

```bash
scp E:\Download\main_config.yaml m1@m1:/home/m1/
ssh m1@m1 "chmod -R u+x ./main_config.yaml"
```

**Ssh into all remote hosts and set passwordless sudo prompt for remote host username (## to be done for all hosts):**

```bash
ssh w1@w1
cat << EOF | sudo tee -a /etc/sudoers > /dev/null
$USER ALL=(ALL) NOPASSWD: ALL
EOF

exit

ssh m1@m1
cat << EOF | sudo tee -a /etc/sudoers > /dev/null 2>&1
$USER ALL=(ALL) NOPASSWD: ALL
EOF

```

**Run ./infrastructure/start.sh script on the master remote host:**

```bash
./infrastructure/start.sh -c "/home/m1/main_config.yaml"
```
