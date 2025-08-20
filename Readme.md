
# Kong Plugin Development Environment

This repository provides a quick and easy way for developers to set up and test their own Kong plugins using Terraform and Docker.

## Prerequisites

Make sure you have the following installed on your machine:

- [Terraform](https://www.terraform.io/downloads.html) (>= 0.12)
- [Docker](https://docs.docker.com/get-docker/)
- [Lua](https://www.lua.org/download.html) (or ``brew install lua``)

## Getting Started

### 1. Clone the Repository

```sh
git clone https://github.com/yourusername/kong-plugin-playground.git
cd kong-plugin-playground/terraform/env-setup
```

### 2. Initialize and Apply Terraform Configuration

Run the following commands to initialize Terraform and create the necessary resources:

```sh
terraform init
terraform apply
```

This will:

1. Pull the latest Kong Docker image.
2. Create a Docker container for Kong with the necessary ports exposed.
3. Mount your plugin code and configuration file into the Kong container.

### 3. Develop Your Plugin

Your plugin code should be placed in the `kong/plugins/my-plugin` directory. The file structure should look something like this:

```

kong/
   └── plugins/
       └── my-plugin/
           ├── handler.lua
           └── schema.lua
```

### 4. Configure Kong

The `kong.yml` file should contain your declarative configuration for Kong, including any routes, services, and plugins you want to set up. For example:

```yaml
_format_version: "2.1"
services:
- name: example-service
  url: http://mockbin.org
  routes:
  - name: example-route
    paths:
    - /

plugins:
- name: my-plugin
  service: example-service
```

### 5. Start Kong

After placing your plugin code and configuration, run the following command to start Kong with your plugin:

```sh
terraform apply
```

This command will start Kong with the specified configuration in `kong.yml`.

### 6. Test Your Plugin

You can test your plugin by sending requests to the configured routes. For example:

```sh
curl -i http://localhost:8000/
```

## Cleaning Up

To destroy the created resources, run:

```sh
terraform destroy
```

This will stop and remove the Docker container and clean up any other resources created by Terraform.

## Contributing

If you find any issues or have suggestions for improvements, please open an issue or submit a pull request.

## License

This project is licensed under the MIT License.

---
