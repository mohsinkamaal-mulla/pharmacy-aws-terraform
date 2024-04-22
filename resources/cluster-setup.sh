#!/bin/bash

kubectl create secret generic aws-creds --from-file=creds=./aws-creds.conf
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.9.1/cert-manager.yaml
