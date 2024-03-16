#!/bin/bash

set -e

UPGRADE_OUTPUT=$(rpm-ostree upgrade --check)

echo "UPGRADE_OUTPUT: $UPGRADE_OUTPUT"

if [[ $UPGRADE_OUTPUT == *"No upgrade available."* ]]; then
    echo "No upgrade available."
    exit 0
fi

curl -w -X POST -H "Content-Type: application/json" 'http://signal-restapi' \
    -d "{\"message\": \"Updating $HOSTNAME, rebooting now.\", \"number\": \"+NUMBER HERE\", \"recipients\": [ \"+NUMBER HERE\" ]}" \
    || echo "failed to send to signal-restapi"

rpm-ostree upgrade --reboot