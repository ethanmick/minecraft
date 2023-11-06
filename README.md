```
MY_IP=$(curl -s https://ipinfo.io/ip)
export TF_VAR_my_ip=$MY_IP

terraform apply
```
