#!/usr/bin/env bash

#-------- Deploy Knative Application
# https://knative.dev/docs/serving/services/creating-services/#procedure
cat <<EOF | kubectl apply -f -
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: hello
spec:
  template:
    spec:
      containers:
        - image: gcr.io/knative-samples/helloworld-go
          ports:
            - containerPort: 8080
          env:
            - name: TARGET
              value: "Knative"
EOF
# To deploy with kn CLI :
# kn service create hello --port 8080 --image gcr.io/knative-samples/helloworld-go

# Now that you have deployed the service, Knative will perform the following steps:
# - Create a new immutable revision for this version of the app.
# - Perform network programming to create a route, ingress, service, and load balancer for your app.
# - Automatically scale your pods up and down based on traffic, including to zero active pods.


# Wait for Knative Service to be Ready
kubectl wait ksvc hello --all --timeout=-1s --for=condition=Ready

# Get the URL of the new Service
SERVICE_URL=$(kubectl get ksvc hello -o jsonpath='{.status.url}')
echo $SERVICE_URL

#-------- Test the App
curl $SERVICE_URL

# Check the pods : after a few seconds without activity => the dpeloment is scaled down to zero
watch -n 1 'kubectl get pod -l serving.knative.dev/service=hello'
# Check the deployment : after a few seconds without activity => the dpeloment is scaled down to zero
watch -n 1 'kubectl get deploy -l serving.knative.dev/service=hello'


# Check the app in the browser
xdg-open $SERVICE_URL

# Check the pod
kubectl get pod -l serving.knative.dev/service=hello -w

# Check Knative resources
k get cm config-autoscaler -o yaml 
k get configurations.serving.knative.dev
k get ingresses.networking.internal.knative.dev
k get metrics.autoscaling.internal.knative.dev
k get podautoscalers.autoscaling.internal.knative.dev
k get revisions.serving.knative.dev
k get routes.serving.knative.dev
k get serverlessservices.networking.internal.knative.dev
k get services.serving.knative.dev

#-------- Concepts :
#
# - Autoscaling
#     - General :https://knative.dev/docs/serving/autoscaling/autoscaling-concepts/
#     - Scale bounds : https://knative.dev/docs/serving/autoscaling/scale-bounds/
#
# - Burst Capacity : https://knative.dev/docs/serving/autoscaling/target-burst-capacity/
# 
# - requests per second target : https://knative.dev/docs/serving/autoscaling/rps-target/


#-------- Monitoring : https://knative.dev/docs/serving/installing-logging-metrics-traces/
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.17.0/monitoring-core.yaml
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.17.0/monitoring-metrics-prometheus.yaml
kubectl get pods --namespace knative-monitoring --watch

# Accessing metrics : https://knative.dev/docs/serving/accessing-metrics/
kubectl port-forward --namespace knative-monitoring \
$(kubectl get pods --namespace knative-monitoring \
--selector=app=grafana --output=jsonpath="{.items..metadata.name}") \
3000 &


#-------- Autoscale app : https://knative.dev/docs/serving/autoscaling/autoscale-go/
cat autoscale-go.yaml
kubectl apply -f autoscale-go.yaml
# Check svc URL
kubectl get ksvc autoscale-go
# Make a request to the autoscale app to see it consume some resources.
curl "http://autoscale-go.default.127.0.0.1.nip.io?sleep=100&prime=10000&bloat=5"

# Observe pods :
kubectl get deploy -w

# Observe dashboard : 
xdg-open http://localhost:3000/d/u_-9SIMiz/knative-serving-scaling-debugging?orgId=1&from=now-5m&to=now&refresh=5s

# Send 30 seconds of traffic maintaining 50 in-flight requests.
hey -z 30s -c 50 \
  "http://autoscale-go.default.127.0.0.1.nip.io?sleep=100&prime=10000&bloat=5" \
  && kubectl get pods

#-------- Blue/Green deployment
# https://knative.dev/docs/serving/samples/blue-green-deployment/

#-------- Routing
# https://knative.dev/docs/serving/samples/knative-routing-go/

#-------- Other samples
# https://knative.dev/docs/serving/samples/hello-world/
