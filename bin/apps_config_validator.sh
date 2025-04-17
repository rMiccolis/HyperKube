#!/bin/bash

YAML_FILE="$1"

if [ ! -f "$YAML_FILE" ]; then
  echo "File not found: $YAML_FILE"
  exit 1
fi

project_count=$(yq '.projects | length' "$YAML_FILE")
if [[ "$project_count" -eq 0 ]]; then
  echo "No projects found in the YAML file."
  exit 1
fi

echo " Found $project_count projects. Starting validation..."

valid="true"

for i in $(seq 0 $((project_count - 1))); do
  name=$(yq ".projects[$i].name" "$YAML_FILE")
  namespace=$(yq ".projects[$i].namespace" "$YAML_FILE")
  repo=$(yq ".projects[$i].github_repo" "$YAML_FILE")
  port=$(yq ".projects[$i].port" "$YAML_FILE")
  service_name=$(yq ".projects[$i].service_name" "$YAML_FILE")

  echo " Validating project [$i]: $name"

  # Required fields check
  if [[ "$name" == "null" || "$namespace" == "null" || "$repo" == "null" ]]; then
    echo "  Error: missing one or more required fields (name, namespace, github_repo)"
    valid="false"
  fi

  # If 'port' is defined, 'service_name' must be too
  if [[ "$port" != "null" && "$service_name" == "null" ]]; then
    echo "  Error: 'port' is defined but 'service_name' is missing"
    valid="false"
  fi

  # Validate environment variables
  env_count=$(yq ".projects[$i].env | length" "$YAML_FILE" 2>/dev/null || echo 0)
  if [[ "$env_count" -gt 0 ]]; then
    for j in $(seq 0 $((env_count - 1))); do
      env_name=$(yq ".projects[$i].env[$j].name" "$YAML_FILE")
      env_value=$(yq ".projects[$i].env[$j].value" "$YAML_FILE")
      if [[ "$env_name" == "null" || "$env_value" == "null" ]]; then
        echo "  Error in env[$j]: 'name' or 'value' is missing"
        valid="false"
      fi
    done
  fi
done

if $valid; then
  echo " All projects and env variables are valid!"
  exit 0
else
  echo "Some projects or env variables are invalid."
  exit 1
fi
