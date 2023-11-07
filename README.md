```
MY_IP=$(curl -s https://ipinfo.io/ip)
export TF_VAR_my_ip=$MY_IP

terraform apply
```

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

mkdir -p /mnt/efs/data
cd /mnt/efs
docker compose up -d

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
