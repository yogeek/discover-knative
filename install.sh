#!/usr/bin/env bash

#-------- Create cluster
kind create cluster --name knative --config ./clusterconfig.yaml

#-------- Check cluster
kubectl cluster-info

#-------- Install Knative (https://knative.dev/docs/install/)
export KNATIVE_VERSION="0.17.2"
kubectl apply -f https://github.com/knative/serving/releases/download/v$KNATIVE_VERSION/serving-crds.yaml
kubectl apply -f https://github.com/knative/serving/releases/download/v$KNATIVE_VERSION/serving-core.yaml
# Wait for Knative installation to be ready
kubectl wait deployment --all --timeout=-1s --for=condition=Available -n knative-serving

# Knative Components
# https://knative.dev/docs/serving/knative-kubernetes-services/

#-------- Install Kourrier Network
# Kourier is an Ingress for Knative Serving : https://github.com/knative-sandbox/net-kourier  
# Kourier is a lightweight alternative for the Istio ingress as its deployment consists only of an Envoy proxy and a control plane for it.
export KNATIVE_NET_KOURIER_VERSION="0.17.0"
kubectl apply -f https://github.com/knative/net-kourier/releases/download/v$KNATIVE_NET_KOURIER_VERSION/kourier.yaml
# Wait for Kourrier installatin to be ready
kubectl wait deployment --all --timeout=-1s --for=condition=Available -n kourier-system

#-------- Configure DNS

# Set the environment variable EXTERNAL_IP to External IP Address of the Worker Node
EXTERNAL_IP="127.0.0.1"
# Set the environment variable KNATIVE_DOMAIN as the DNS domain using nip.io
KNATIVE_DOMAIN="$EXTERNAL_IP.nip.io"
echo KNATIVE_DOMAIN=$KNATIVE_DOMAIN
# Double check DNS is resolving
dig $KNATIVE_DOMAIN
# Configure DNS for Knative Serving
kubectl patch configmap -n knative-serving config-domain -p "{\"data\": {\"$KNATIVE_DOMAIN\": \"\"}}"

#-------- Configure Kourier 
# Configure Kourrier Service to listen for http port 80 on the node
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: kourier-ingress
  namespace: kourier-system
  labels:
    networking.knative.dev/ingress-provider: kourier
spec:
  type: NodePort
  selector:
    app: 3scale-kourier-gateway
  ports:
    - name: http2
      nodePort: 31080
      port: 80
      targetPort: 8080
EOF

#-------- Configure Knative to use Kourier
kubectl patch configmap/config-network \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"ingress.class":"kourier.ingress.networking.knative.dev"}}'

#-------- Check Knative is installed correctly
kubectl get pods -n knative-serving
kubectl get pods -n kourier-system
kubectl get svc  -n kourier-system kourier-ingress
