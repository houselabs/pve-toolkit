
## create-cloud-template.sh
This script is forked from https://gist.github.com/chriswayg/43fbea910e024cbe608d7dcb12cb8466

### How to use:
Pre-req:
- run on a Proxmox 6 server
- a dhcp server should be active on vmbr0

- fork the gist and adapt the defaults as needed
- download the script into /usr/local/bin/
- chmod +x /usr/local/bin/create-cloud-template.sh
- prepare a /root/.ssh/2019_id_rsa.pub as your ssh public key
- prepare a cloudinit user-config.yml in the working directory (optional)
- run the script
- clone the template from the Proxmox GUI and test
