#!/bin/bash 

oc patch sts mycluster-amq-broker-ss -p "$(<kustomize/patch.yaml)"