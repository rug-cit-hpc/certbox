# Certbox

This repository contains playbooks and documentation to deploy an ACME client capable of requesting,
storing and automatically renewing a configured set of certificates (Certbox), along with 
configurations for services to retrieve the certificates from it.

## How it works

### Certbox

The Certbox machines is a wrapper around [certbot](https://certbot.eff.org/). It first installs certbot 
through snap (the recommended install procedure), and then, for each configured certificate, it asserts
that the domain matches a configured allowed domain list, abd that it is resolvable, and then it requests
the certificate through certbot. Since certbot automatically takes care of renewing the certificates with 
a systemd timer, Certbox also does this.

Compared to a normal certbot installation, Certbox associates each certificate with its specified user,
creating it if does not exist yet. This ensures that each service can only access the certificate that 
belongs to it.

Since the Certbox ansible role does not have functionality for revoking or modifying certificates, these
operations must be performed by calling the certbot commands directly on the machine (with root privilege).

### Certificate Clients 

The machines requesting certificates through Certbox are set up with the cert_client ansible role. This 
sets up a daily cron job for the root user which runs a script that copies the current certificate from 
Certbox, compares it against the current certificate in the client, and if they differ, replaces it with 
the new one and calls the `/etc/pki/register_new_certificate.sh` script. This script must be then set up
manually to restart the service (or perform any action that ensures the new certificate will be used).
The certificate is always put in the `/etc/pki` directory, with the same name as the Certbox certificate
name.

## Setup

### Requirements
- a machine capable of running Ansible, used to deploys the system 
- a VM running Rocky Linux 9, with root access, on which Certbox will be deployed.  
- root access on the services machines requiring certificates. Additionally, these machines must
be able to reach the Certbox machine through ssh. 

### Installation
Installing Certbox is done by running the ansible roles with the correct configuration on the 
proper hosts.

A quick way of doing this is as follows:
- clone the current repo on your (ansible) machine
- edit the configuration for the certbox role (see below)
- rename the main.yml.example file and adapt it with the correct hosts and variables
- run the main ansible playbook
```commandline
ansible-playbook main.yml
```

### Configuration

#### certbox

All the configuration for the certbox role can be done by modifying the `roles/certbox/defaults/main.yml` 
file. For certbox to run, correct values for following parameters must be set:
- `certbox_email`: This is the email provided to the ACME server. Usually, the ACME server will
mail this address when a certificate is about to expire.
- `certbox_domain`: This is the domain of the ACME server used.
- `certbox_eab_kid` and`certbox_eab_hmac_key`: credentials for the ACME server account through which
certificates are requested.

By default, the parameters above are sourced from the environment variables `CERTBOX_EMAIL`, 
`CERTBOX_ACME_SERVER`, `CERTBOX_EAB_KID` and `CERTBOX_EAB_HMAC_KEY`. If any of the parameters 
is missing, the role will not execute and show an error instead.

The `certbox_cmd` parameters is used to adjust the command passed to certbot. This should not be
modified (unless you know what you are doing). 

The parameter `certbox_allowed_domains` specifies a list of domains for which Certbox will be allowed 
to request certificates. For a domain to be eligible for that, it must end with any of elements of 
this parameter. 

E.g. if the `hpc.rug.nl` value is the only element for this parameter, Certbox will create 
certificates for the domain `portal.hb.hpc.rug.nl` or anything ending with `hpc.rug.nl`, but no
other domains.

The last parameter `certbox_domains` configures what certificates Certbox requests. It must be a
list parameter, where each entry must contain the following attributes:
- `name` - the internal name for the certificate that certbot uses. Additionally, the services
requiring certificates from certbox will use this to identify which certificate they get. 
- `domain` - the domain for which the certificate is requested. The domain must resolve for a
certificate to be created for it.
- `user` - the username for the user which will be set as owner of the certificate. This is done
to ensure that each client can only access its certificate. The user is created if it does not
exist already.
- `deployhook` (optional) - specifies a command that is run on the certbox machine everytime a 
certificate is successfully renewed. The command must not contain the " character. 
- `key` (optional) - SSH public key to be added to the user, in order to allow the clients to 
copy the certificate by connecting through SSH.

Adding additional certificates and running the role again will not affect previously existing 
certificates. Modifying the `key` parameter will add the new key to the user. **Modifying any other
parameter from an already deployed entry will result in errors.**

#### cert_client

The cert_client role requires four parameters: 
- `cert_client_certbox_domain` - the domain through which the client accesses the Certbox machine
- `cert_client_username` - the user on the Certbox machine to which the client connects
- `cert_client_cert_name` - the Certbox name for the certificate the client uses. This will also
be the name of the certificate file on the client, in the `etc/pki` directory
- `cert_client_key_name` - the name of the certificate private key file, in the same directory

From these, only the `cert_client_certbox_domain` should be defined in the 
`roles/cert_client/defaults/main.yml`, as all the clients should connect to the same Certbox
machine. The other parameters need to be defined on a service by service basis, so they should
be passed as either play variables, when the roll is called,
```yaml
- name: 'Deploy Client'
  hosts: client_host
  roles:
    - cert_client
  vars:
    cert_client_username: example-cert-user
    cert_client_cert_name: example-cert
    cert_client_key_name: example-key
```
or as ansible host variables.
```yaml
client_host:
  ansible_host: 192.168.0.5
  cert_client_username: 'example-cert-user'
  cert_client_cert_name: 'example-cert'
  cert_client_key_name: 'example-key'
```