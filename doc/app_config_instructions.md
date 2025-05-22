# Instructions to generate a correct apps_config.yaml configuration

This file lets you provide informations on how to install and deploy your custom applications to the cluster.
It supports the execution of '.sh' files inside your app:

- **exec_script_before_deploy**: Here you can specify the execution call to a ".sh" file. This is executed BEFORE the /kubernetes folder  inside your project is applied to the cluster. For example if you have a "build.sh" file inside a bin folder you could set this to:

    ```yaml
    exec_script_before_deploy: 'bin/build.sh -s 1 -c 1 -b input-tls -p https -i $app_server_addr -d $docker_username -t 1'
    ```

    For the list of variables you can use see: [Environment Variables](#environment-variables-usable-inside-exec_script_before_deploy-or-exec_script_after_deploy-and-env_subsitution-folder)

- **exec_script_after_deploy**:  Here you can specify the execution call to a ".sh" file. This is executed AFTER the "/kubernetes" folder inside your project is applied to the cluster. It has all the same behavior of "exec_script_before_deploy"

You can find an example of [apps_config.yaml](https://github.com/rMiccolis/HyperKube/blob/master/doc/apps_config.yaml)

## Required Fields

Each project in the projects list must include:

  Field:        Description:

- name:         Name of the project
- namespace     Kubernetes namespace for deployment
- github_repo:  GitHub repository containing the project code

## Optional Fields

Each project in the projects list must include:

  Field:                        Description:

- port:                         External port for ingress (e.g. 27017 for MongoDB). This will open a port inside NGINX ingress controller
- service_name:                 Service name to use for the ingress route (required if port is specified)
- exec_script_before_deploy:    Relative path to the script to run before deploying the project (optional). You can use a set of already defined environment variables in this script. It's even possible to use them as parameter of script inside 'exec_script_before_deploy'. [Example](#example-of-execution-of-a-script-before-deploying)
- exec_script_after_deploy:     Relative path to the script to run after deployment (optional). You can use a set of already defined environment variables in this script. It's even possible to use them as parameter of script inside 'exec_script_after_deploy'. [Example](#example-of-execution-of-a-script-before-deploying)

## Environment Variables (env)

Each project can include an optional list of environment variables under env. Every environment variable object must contain at least:

  Field:                        Description:

- name:                         the environment variable name.

- value:                        the environment variable value.

- Optionally, you can include:

- base64_encoding:              set to 'true' if the value should be base64 encoded before being passed (useful for secrets)

```yaml
env:
  - name: some_var
    value: some_value
    base64_encoding: 'true'
```

## Validation

You can use the included ./bin/apps_config_validator.sh script to check the structure of your projects.yaml file:

```yaml
. ./bin/apps_config_validator.sh /home/$USER/apps_config.yaml
```

The validation checks for:

- Presence of required fields

- Correctness of env variables (must include name and value)

- Dependency between port and service_name

## Notes

- **If a tls certificate (.pem file) is needed, "tls-cert.pem" file is generated inside /home/$USER/tls/**

- The GitHub repository is cloned automatically before deployment.

- Environment variables marked with base64_encoding: 'true' will be encoded before being injected into Kubernetes secrets.

## Environment Variables usable inside exec_script_before_deploy or exec_script_after_deploy and env_subsitution folder

- repository_root_dir       => this is the /home/$USER folder
- app_server_addr           => this is the IP address of your load balancer (your public IP)
- application_dns_name      => this is the dns name of your public IP (your_dns.com)
- master_host_ip_eth0       => the master host IP in eth0 interface
- master_host_ip            => the actual master host IP used inside cluster (can be on wireguard interface or eth0)
- master_host_ip_vpn        => the master host IP in wireguard interface
- master_host_name          => the name of the master host
- host_list                 => list of strings containing the hosts IPs of hosts inside cluster (w1@192.168.1.201@10.11.1.2 w2@192.168.1.202@10.11.1.3)
- github_branch_name        => the branch name of HyperKube project used
- docker_username
- docker_access_token

You can use all these variables + all the variables you provided inside project.env inside apps_config.yaml in the form of ${var} or $var

**Important**: All variables inside your project "env_subsitution" folder files, in the format of ${var} or $var, will be subsituted with the value of the environment variables written up.
This operation is performed **BEFORE** the execution of exec_script_before_deploy and exec_script_after_deploy!
Example: if there is a values.yaml with a row like: path: ${repository_root_dir}, it will be substituted with: path: /home/$USER

### Example of execution of a script before deploying

Here you can enter the path of the script to be executed (bin/build.sh or /bin/build.sh, just the relative path, feel free to choose the file name) and even a set of parameters. [Environment Variables](#environment-variables-usable-inside-exec_script_before_deploy-or-exec_script_after_deploy-and-env_subsitution-folder) can be used even as parameters to your scripts:

```yaml
exec_script_before_deploy: 'bin/build.sh -s 1 -c 1 -b input-tls -p https -i $app_server_addr -d $docker_username -t 1'
```
