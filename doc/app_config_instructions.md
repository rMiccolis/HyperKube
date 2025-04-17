# Instructions to generate a correct app_yaml_variables.yaml configuration

## Required Fields

Each project in the projects list must include:

  Field:        Description:

- name:         Name of the project
- namespace     Kubernetes namespace for deployment
- github_repo:  GitHub repository containing the project code

## Optional Fields

Each project in the projects list must include:

  Field:                        Description:

- port:                         External port for ingress (e.g. 27017 for MongoDB)
- service_name:                 Service name to use for the ingress route (required if port is specified)
- exec_script_before_deploy:    Script to run before deploying the project (optional)
- exec_script_after_deploy:     Script to run after deployment (optional)

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

You can use the included ./bin/app_config_validator.sh script to check the structure of your projects.yaml file:

```yaml
. ./bin/app_config_validator.sh /home/$USER/app_yaml_variables.yaml
```

The validation checks for:

- Presence of required fields

- Correctness of env variables (must include name and value)

- Dependency between port and service_name

## Notes

- The GitHub repository is cloned automatically before deployment.

- Environment variables marked with base64_encoding: 'true' will be encoded before being injected into Kubernetes secrets.

## Variables usable inside exec_script_before_deploy/exec_script_after_deploy

- repository_root_dir       => this is the /home/$USER/ folder
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
