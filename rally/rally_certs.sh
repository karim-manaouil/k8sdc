#!/bin/bash

# Exctract certificates from kubeconfig

python -c "import yaml; obj=yaml.load(open('/root/.kube/config'), Loader=yaml.Loader); print(obj['clusters'][0]['cluster']['certificate-authority-data'])"|
	base64 --decode > ca.crt
python -c "import yaml; obj=yaml.load(open('/root/.kube/config'), Loader=yaml.Loader); print(obj['users'][0]['user']['client-certificate-data'])" |
	base64 --decode > client.crt
python -c "import yaml; obj=yaml.load(open('/root/.kube/config'), Loader=yaml.Loader); print(obj['users'][0]['user']['client-key-data'])" |
	base64 --decode > client.key
