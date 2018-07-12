# Chef HA Terraform

Consists of
* Chef HA frontend instances load balanced by an ALB with a certificate from ACM
* A Chef Backend cluster.
* Route53 DNS records

Currently only installing the Chef Server and Backend packages, no configuration undertaken - is left as an exercise to the reader.

Inspiration from https://github.com/mengesb/tf_hachef

## Frontend Manual Config
* Visit: https://docs.chef.io/install_server_ha.html
* All FEs: sudo cp chef-server.rb /etc/opscode/chef-server.rb
* FE1: sudo chef-server-ctl reconfigure
* FE1: scp /etc/opscode/private-chef-secrets.json ${var.ami_user}@<FE[2,3]_IP>:
* FE1: scp /var/opt/opscode/upgrades/migration-level ${var.ami_user}@<FE[2,3_IP>:
* FE[2,3]: sudo cp private-chef-secrets.json /etc/opscode/private-chef-secrets.json
* FE[2,3]: sudo mkdir -p /var/opt/opscode/upgrades/
* FE[2,3]: sudo cp migration-level /var/opt/opscode/upgrades/migration-level
* FE[2,3]: sudo touch /var/opt/opscode/bootstrapped
* FE[2,3]: sudo chef-server-ctl reconfigure

## Backend Manual Config
* Visit: https://docs.chef.io/install_server_ha.html
* Leader (BE1): sudo chef-backend-ctl create-cluster
* Leader (BE1): scp /etc/chef-backend/chef-backend-secrets.json ${var.ami_user}@<BE[2,3]_IP>:
* Follower (BE[2,3]): sudo chef-backend-ctl join-cluster <BE1_IP> --accept-license -s chef-backend-secrets.json -y
* All BEs: sudo rm chef-backend-secrets.json
* All BEs: sudo chef-backend-ctl status
* For FE[1,2,3]: sudo chef-backend-ctl gen-server-config <FE_FQDN> -f chef-server.rb.FE_NAME
* For FE[1,2,3]: scp chef-server.rb.FE_NAME USER@<IP_FE[1,2,3]>:


## Backend failure recovery
https://docs.chef.io/backend_failure_recovery.html
