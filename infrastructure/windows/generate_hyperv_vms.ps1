param(
[string]$main_config_file_path,
[string]$apps_config_file_path,
[string]$mongodb_values_file_path="",
[string]$mongodb_setup_file_path=""
)

# Install NuGet to download and install powershell-yaml to read and parse yaml files
Get-PackageProvider -Name "NuGet" -ForceBootstrap | out-null
Set-PSRepository PSGallery -InstallationPolicy Trusted | out-null
if (!(Get-Module -ListAvailable -Name powershell-yaml)) {
    Install-Module powershell-yaml
}

# READ ALL CONFIGURATION KEYS
Import-Module powershell-yaml
$config=Get-Content $main_config_file_path | ConvertFrom-YAML

# Set the ssh folder where there are all the ssh key pairs
$ssh_path = "$HOME\.ssh"
# Set the path to the public key which has access to github repository
$pub_key_path = "$HOME\.ssh\id_rsa.pub"

# Remove the known_hosts if exists
if (Test-Path -PathType Leaf "$ssh_path\known_hosts" ) {
    Remove-Item -LiteralPath "$ssh_path\known_hosts" -Recurse
}

# Create ssh config file and set ssh agent to automatically accept new hosts
if (!(Test-Path "$HOME\.ssh\config" -PathType Leaf)) {
    New-Item "$HOME\.ssh\config"
    Set-Content "$HOME\.ssh\config" "StrictHostKeyChecking accept-new"
}

# Read public key and encode its content in base64 (we'll use it to feed cloud-init)
$pub_key = Get-Content $pub_key_path
$pub_key_raw = Get-Content "$ssh_path\id_rsa.pub" -Encoding UTF8 -Raw
$bytes_pub_key = [System.Text.Encoding]::UTF8.GetBytes($pub_key_raw)
$encoded_pub_key = [System.Convert]::ToBase64String($bytes_pub_key)

# Read private key and encode its content in base64 (we'll use it to feed cloud-init)
$priv_key = Get-Content "$ssh_path\id_rsa" -Encoding UTF8 -Raw
$bytes_priv_key = [System.Text.Encoding]::UTF8.GetBytes($priv_key)
$encoded_priv_key = [System.Convert]::ToBase64String($bytes_priv_key)

# Read oscdimg path. Oscdimg is used to write the CIDATA image (containing meta-data and user-data files) for cloud init as a ISO 9660 image
$oscdimgPath = $config.oscdimg_path

# Read qemuImg path. Quemu to convert ubuntu cloud-image to a virtual hard drive to be used by virtual machines
$qemuImgPath = $config.qemuimg_path

# Read the path where all the virtual machines will be stored
$vm_store_path = $config.vm_store_path

# Read the path where to find cloud-image of your linux distro
$imagePath = $config.os_image_path

# Read VMs resources
$vm_cpu_count = [int]$config.vm_cpu_count
$vm_min_ram = (Invoke-Expression $config.vm_min_ram)
$vm_max_ram = (Invoke-Expression $config.vm_max_ram)

Write-Output $vm_cpu_count $vm_min_ram $vm_max_ram

# Read the github branch name where to pull the code from
$github_branch_name = $config.github_branch_name

# Initialize the dictionary where to store all processed hosts info
$hosts=@{}

# Reading all hosts info (master and workers)
$all_hosts=@()
$all_hosts+=$config.master_host
$all_hosts+=$config.hosts

# If no path to store VM is found then store them into C:\Users\USERNAME\HyperKube_vm
if (!$vm_store_path) {
    $vm_store_path="$env:USERPROFILE\HyperKube_vm"
    Write-Output "path to store VM is found then store them into $vm_store_path"
}
Write-Output "Generating VMs in $vm_store_path folder"

# Read the Ethernet Adapter device that is providing network to this host
$eth_adapter=Get-NetAdapter -Name "Ethernet"
$eth_adapter=$eth_adapter.InterfaceDescription

# Check for an existing network adapter named: "vEthernet (VM)"
$vm_adapter=Get-NetAdapter -Name "vEthernet (VM)" -ErrorAction SilentlyContinue
# If it does not exists, create it
if (!$vm_adapter) {
    Write-Output "generating Virtual switch 'VM' with adapter: $eth_adapter..."
    New-VMSwitch -Name "VM" -NetAdapterName "Ethernet" | Out-Null
}

# Loop for each host and create its own virtual machine
for ($j=0;$j -lt $all_hosts.Length; $j++) {
    # Read USERNAME@IP and split based on @
    $host_info=$all_hosts[$j].split("@")
    # Save host username
    $host_user=$host_info[0]
    # Save host ip
    $host_ip=$host_info[1]
    $existing_vm=Get-VM -Name $host_user -ErrorAction SilentlyContinue
    if ($existing_vm) {
        Write-Output "Removing $host_user VM from Hyper-V"
        Stop-VM -Name $host_user -ErrorAction SilentlyContinue
        Remove-VMHardDiskDrive -VMName $host_user -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 0
        Remove-VM -Name $host_user -Force
        Remove-Item -LiteralPath $vm_store_path\$host_user -Recurse
    }
}

# if $vm_store_path exists then remove it and generate it from scatch
if (!(Test-Path -Path $vm_store_path)) {
    # Remove-Item -LiteralPath $vm_store_path -Recurse
    Write-Output "Generating $vm_store_path folder... Here will be stored all virtual machines."
    New-Item -Path $vm_store_path -ItemType Directory
}


$master_host_name = ""
$master_host_ip = ""

# Set the mac address of the VM. they will start from 00155D380130,00155D380131, ...
$decimal_host = 3
$unit_host = 0

$last_user=""

# Loop for each host and create its own virtual machine
for ($i=0;$i -lt $all_hosts.Length; $i++) {

    # Read USERNAME@IP and split based on @
    $host_info=$all_hosts[$i].split("@")
    # Save host username
    $host_user=$host_info[0]
    # Save host ip
    $host_ip=$host_info[1]

    $last_user="$host_user@$host_ip"

    # Write host into hosts dictionary
    $hosts[$host_user]=$host_ip

    Write-Output "Setting up $host_user virtual machine..."

    # Encode the main_config.yaml content into base64 (we'll use it to feed cloud-init)
    $encoded_main_config_content="Cg=="
    if ($all_hosts[$i] -eq $config.master_host) {
        $master_host_name = $host_user
        $master_host_ip = $host_ip
        $main_config_content = Get-Content $main_config_file_path -Raw
        $encodedBytes = [System.Text.Encoding]::UTF8.GetBytes($main_config_content)
        $encoded_main_config_content = [System.Convert]::ToBase64String($encodedBytes)


        # Encode the apps_config.yaml content into base64 (we'll use it to feed cloud-init)
        $apps_config_content = Get-Content $apps_config_file_path -Raw
        $encodedBytes = [System.Text.Encoding]::UTF8.GetBytes($apps_config_content)
        $encoded_apps_config_file = [System.Convert]::ToBase64String($encodedBytes)

        # Encode the mongodb_values.yaml content into base64 (we'll use it to feed cloud-init)
        if ($mongodb_values_file_path -eq "") {

            # use load_balancer_dns_name to reach mongodb instance.
            # load_balancer_dns_name is also needed for the tls certificate to work:
            # - extraDnsNames makes bitnami helm chart add a DNS entry for the host aliases inside tls certificate
            $load_balancer_dns_name = $config.load_balancer_dns_name

            # set values for username and psw if are provided
            $mongo_root_username = $config.mongo_root_username
            $mongo_root_password = $config.mongo_root_password
            if (($null -eq $mongo_root_username) -or ($null -eq $mongo_root_password)) {
                # set defaults otherwise
                $mongo_root_username = "mongo_root_username"
                $mongo_root_password = "mongo_root_password"
            }
            $mongodb_values_content = @"
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
"@
        } else {
            $mongodb_values_content = Get-Content $mongodb_values_file_path -Raw
        }
        $encodedBytes = [System.Text.Encoding]::UTF8.GetBytes($mongodb_values_content)
        $encoded_mongodb_values_file = [System.Convert]::ToBase64String($encodedBytes)
        }

        if ($mongodb_setup_file_path -eq "") {
          $mongodb_setup_content = ""
        } else {
          $mongodb_setup_content = Get-Content $mongodb_setup_file_path -Raw
        }
        $encodedBytes = [System.Text.Encoding]::UTF8.GetBytes($mongodb_setup_content)
        # Encode the mongodb_setup.sh content into base64 (we'll use it to feed cloud-init)
        $encoded_mongodb_setup_file = [System.Convert]::ToBase64String($encodedBytes)

    # Set VM Name
    $VMName = $host_user
    # Set Virtual Switch Name
    $virtualSwitchName = 'VM'

    if ($unit_host -gt 9) {
        $decimal_host += 1
        $unit_host = 0
    }
    $mac_address = "00155D3801" + $decimal_host + $unit_host
    $unit_host += 1

    # Virtual Machine data:
    $GuestOSName = $host_user
    $GuestOSID = $mac_address

# Set cloud-init instance-data
$metadata = @"
instance-id: $($GuestOSID)
local-hostname: $($GuestOSName)
"@

# Set cloud-init user-data
$userdata = @"
#cloud-config
package_update: true
package_upgrade: true
users:
 - default
 - name: $($host_user)
   groups: [adm, audio, cdrom, dialout, floppy, video, plugdev, dip, netdev, sudo, users, admin, lxd]
   shell: /bin/bash
   sudo: ['ALL=(ALL) NOPASSWD:ALL']
   ssh_authorized_keys:
   - $($pub_key)
keyboard:
   layout: us
write_files:
 - encoding: b64
   owner: $($host_user):$($host_user)
   path: /home/$($host_user)/.ssh/id_rsa.pub
   content: $($encoded_pub_key)
   permissions: '0600'
   defer: true
 - encoding: b64
   owner: $($host_user):$($host_user)
   path: /home/$($host_user)/.ssh/id_rsa
   content: $($encoded_priv_key)
   permissions: '0600'
   defer: true
 - encoding: b64
   owner: $($host_user):$($host_user)
   content: $($encoded_main_config_content)
   path: /home/$($host_user)/main_config.yaml
   permissions: '0777'
   defer: true
 - encoding: b64
   owner: $($host_user):$($host_user)
   content: $($encoded_apps_config_file)
   path: /home/$($host_user)/apps_config.yaml
   permissions: '0777'
   defer: true
 - encoding: b64
   owner: $($host_user):$($host_user)
   content: $($encoded_mongodb_values_file)
   path: /home/$($host_user)/mongodb_values.yaml
   permissions: '0777'
   defer: true
 - encoding: b64
   owner: $($host_user):$($host_user)
   content: $($encoded_mongodb_setup_file)
   path: /home/$($host_user)/user_custom_scripts/mongodb_setup.sh
   permissions: '0777'
   defer: true
 - encoding: b64
   owner: $($host_user):$($host_user)
   content: Cg==
   path: /home/$($host_user)/.ssh/known_hosts
   permissions: '0777'
   defer: true
power_state:
   mode: reboot
   timeout: 30
   condition: True
runcmd:
 - "ssh-keyscan github.com >> /home/$($host_user)/.ssh/known_hosts"
 - "echo 127.0.1.1 $($host_user) >> /etc/hosts"
"@

    # Set temp path to store temporary files
    $tempPath = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
    # Make temp location
    md -Path $tempPath | out-null
    md -Path "$($tempPath)\Bits" | out-null

    # Set the Path where to store the metadata.iso file in ISO 9660, made up from meta-data and user-data files
    $metaDataIso = "$($vm_store_path)\$host_user\metadata.iso"

    # If virtual machine with same name already exists, delete it
    $VM_exist = Get-VM -name $VMName -ErrorAction SilentlyContinue | ConvertTo-Json | ConvertFrom-Json
    $VM_exist_name = $VM_exist.Name
    if ($VM_exist_name) {
        Write-Output "Removing already existing VM $VM_exist_name..."
        Remove-VM -Name $VMName -Force
        if (Test-Path -Path "$vm_store_path\$host_user") {
            Start-Sleep -Seconds 120
            Remove-Item -LiteralPath "$vm_store_path\$host_user" -Recurse
        }
    }

    # Create the vm specific folder
    New-Item -Path "$vm_store_path\$host_user" -ItemType Directory | out-null

    # Output meta and user data to files meta-data and user-data in the temp directory
    sc "$($tempPath)\Bits\meta-data" ([byte[]][char[]] "$metadata") -Encoding Byte
    sc "$($tempPath)\Bits\user-data" ([byte[]][char[]] "$userdata") -Encoding Byte

    # Convert cloud image to VHDX
    $vhdx = "$vm_store_path\$host_user\test.vhdx"
    & $qemuImgPath convert -f qcow2 $imagePath -O vhdx -o subformat=dynamic $vhdx
    Resize-VHD -Path $vhdx -SizeBytes 50GB

    # Create meta data ISO image
    & $oscdimgPath "$($tempPath)\Bits" $metaDataIso -j2 -lCIDATA

    # Clean up temp directory
    rd -Path $tempPath -Recurse -Force

    Write-Output "Generating VM $host_user with mac address: $mac_address"

    # Create New Virtual Machine
    New-VM -Name $VMName -Generation 2 -VHDPath $vhdx -Path "$vm_store_path\$VMName" -SwitchName $virtualSwitchName
    # Set the RAM
    Set-VMMemory $VMName -DynamicMemoryEnabled $True -MinimumBytes $vm_min_ram -StartupBytes $vm_min_ram -MaximumBytes $vm_max_ram
    # Set number of CPUs
    Set-VMProcessor $VMName -Count $vm_cpu_count
    # Add DVD Drive to Virtual Machine with the metadata files for cloud-init
    Add-VMDvdDrive -VMName $VMName -Path $metaDataIso
    # Set the created 'VM' network adapter
    Set-VMNetworkAdapter -VMName $VMName -StaticMacAddress $mac_address

    # Disable Secure Boot
    Set-VMFirmware -VMName $VMName -EnableSecureBoot "Off"
    Write-Output "$host_user Virtual Machine installed at $vm_store_path\$host_user"
    Write-Output "Booting up $host_user virtual machine and preparing for first boot..."
    # Start the VM
    Start-VM -Name $host_user
}

Write-Output "Starting application installation..."

Write-Output "Waiting for $master_host_name virtual machine to fully boot up..."
$vm_ready = $False
# Test periodically if the master vm is up to execute the clone of the code from repository
while ($vm_ready -eq $False) {
    Start-Sleep -Seconds 120
    if (Test-NetConnection $master_host_name | Where-Object {$_.PingSucceeded -eq "True"}) {
        $work = 1
        $seconds = 30
        while ($work -eq 1) {
            $seconds = $seconds + 5
            Start-Sleep -Seconds $seconds

            # Check if cloud-init status: if cloud-init has done we can proceed with the git clone
            $cloud_init_status = ssh $master_host_name@$master_host_ip "cloud-init status"
            if ($cloud_init_status -Match "done") {
                Start-Sleep -Seconds 90
                if (Test-NetConnection $master_host_name | Where-Object {$_.PingSucceeded -eq "True"}) {
                    $work = 0
                    $vm_ready = $True
                    # ssh-keyscan $master_host_ip | Out-File -Filepath "$HOME/.ssh/known_hosts" -Append
                    Write-Output "Cloning branch $github_branch_name..."
                    # Cloning the github repository code of the specified branch
                    ssh $master_host_name@$master_host_ip "git clone --single-branch --branch $github_branch_name 'git@github.com:rMiccolis/HyperKube.git' '/home/$master_host_name/HyperKube'"
                    ssh $master_host_name@$master_host_ip "chmod u+x /home/$master_host_name/HyperKube -R"
                    # Open a cmd shell and automatically ssh into master virtual machine
                    Start-Process -Verb RunAs cmd.exe -Args '/c', "ssh $master_host_name@$master_host_ip && pause"
                    # Copy to clipboard the command to be executed on the just opened cmd shell to run all the infrastructure setup
                    # You just have to paste the command and then enter
                    Set-Clipboard -Value "./HyperKube/infrastructure/start.sh -c '/home/$master_host_name/main_config.yaml'"
                }
            } else {
                Write-Output "$master_host_name@$master_host_ip => cloud-init $cloud_init_status"
            }
        }
    }
}

Write-Output "Done! All hosts are configured."
Write-Output "To start the infrastructure setup run this command on the just opened cmd:"
Write-Output "./HyperKube/infrastructure/start.sh -c '/home/$master_host_name/main_config.yaml'"
Write-Output "(This command is already copied in the clipboard, you just have to paste it and run it)"
