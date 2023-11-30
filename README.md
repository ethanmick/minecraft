# Minecraft: On Demand

Playing Minecraft with friends on a multiplayer server is a lot fun. It's more
fun when you have control over the server and can add mods, customizations, and
have a map that shows the world you have explored. This isn't possible on Realms, but is when you control your own server.

Running a server that can play Minecraft can be expensive. But that's only if
you leave it running all the time. You probably aren't playing all the time, so
when you are done playing it would be perfect for the server to shut itself off.

This project uses Terraform to create a Minecraft instance that auto-shuts off
after 5 minutes of inactivity.

## Usage

You will need an AWS account to run this.

This project has several parts. In essence, it's an EC2 instance that runs
within an autoscaling group. The group scales up and down to start and stop
the instance. The instance is a custom built Ubuntu image.

### Packer

Packer is used to build or update the AMI.

```bash
cd ami
packer build ubuntu.pkr.hcl
```

This will build the AMI and host it in the account. This AMI is then used in the
`minecraft.tf` file to run that image.

### Terraform

```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_REGION=aws_region #us-east-1, us-west-1, etc. Pick the region closest to you.

terraform apply
```

This will create the necessary foundation, but won't launch an instance. To do that, we have a Discord bot.

```
/minecraft
```

This will spin up the server and let you play.

## Architecture

### Discord Bot

## Setup

```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install -y curl
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo docker image pull itzg/minecraft-server

```

```yaml
version: '3'

services:
  mc:
    image: itzg/minecraft-server
    ports:
      - 25565:25565
    environment:
      EULA: 'TRUE'
      MEMORY: 3G
      EXISTING_WHITELIST_FILE: SYNCHRONIZE
      WHITELIST: |
        Abattoir
      EXISTING_OPS_FILE: SYNCHRONIZE
      OPS: |
        Abattoir
    tty: true
    stdin_open: true
    restart: unless-stopped
    volumes:
      - ./data:/data
```
