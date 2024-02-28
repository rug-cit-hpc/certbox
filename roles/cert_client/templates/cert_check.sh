#
# This file is deployed with the cert_client role from an Ansible playbook.
# DO NOT EDIT MANUALLY; update source and re-deploy instead!
#

CERTBOX_PATH="{{ cert_client_username }}@{{ cert_client_certbox_domain }}:/etc/letsencrypt/live/{{ cert_client_cert_name }}"

echo "Grabbing latest certificate from certbox:${CERTBOX_PATH}"

if
  scp -o StrictHostKeyChecking=accept-new ${CERTBOX_PATH}/fullchain.pem /tmp/~newcert.pem && \
  scp -o StrictHostKeyChecking=accept-new ${CERTBOX_PATH}/privkey.pem /tmp/~newkey.pem;
then
  echo "Copied over files from certbox"
else
  echo "Failed to copy files. Abort operation."
  exit 1
fi

if [ ! -f /etc/pki/{{ cert_client_cert_name }}.pem ];
then
  echo "No old certificate detected."
  touch /etc/pki/{{ cert_client_cert_name }}.pem
fi

if ! cmp -s /etc/pki/{{ cert_client_cert_name }}.pem /tmp/~newcert.pem
then
  echo "New certificate detected. Putting it in the place of the old one"
  cp -f /tmp/~newcert.pem /etc/pki/{{cert_client_cert_name}}.pem
  cp -f /tmp/~newkey.pem /etc/pki/{{cert_client_key_name}}.pem
  /etc/pki/register_new_certificate.sh
else
  echo "Already using this certificate"
fi

rm -f /tmp/~newcert.pem
rm -f /tmp/~newkey.pem

exit 0
