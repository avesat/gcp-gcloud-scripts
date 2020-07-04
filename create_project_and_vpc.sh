#!/bin/bash

if [ "$#" -lt 1 ]; then
   echo "Usage:   ./create_projects.sh Billing ID"
   echo "example: ./create_projects.sh 0X0X0X-0X0X0X-0X0X0X"
   exit
fi

if (! gcloud beta billing accounts list | grep $1) then
   echo "Invalid billing accout id: $1"
   echo "billing accout id must be one of:"
   echo "$(gcloud beta billing accounts list)"
   exit
fi

PROJECT_NAME=gcp-project
PROJECT_ID=$PROJECT_NAME-120919
BILLING_ID=$1
VPC_NAME=$PROJECT_NAME-vpc1
SUBNET_NAME=$VPC_NAME-subnet1

### Create GCP project
gcloud projects create $PROJECT_ID --name=$PROJECT_NAME --set-as-default
gcloud config set compute/zone europe-west3
gcloud config set compute/region europe-west3-a

### Link billing account id to the project
gcloud beta billing projects link $PROJECT_ID \
	--billing-account $BILLING_ID

### Create VPC
gcloud services enable compute.googleapis.com -q
gcloud compute networks create $VPC_NAME --subnet-mode=custom
gcloud compute networks subnets create $SUBNET_NAME \
	--network=$VPC_NAME \
	--range=10.0.0.0/24 \
	--region=europe-west3

### Create ACL rule
gcloud compute firewall-rules create allow-https \
	--network $VPC_NAME \
	--allow tcp:433,icmp

### Create default route
gcloud compute routes create $VPC_NAME-default-route \
	--destination-range=0.0.0.0/0 \
	--next-hop-gateway=default-internet-gateway \
	--network=$VPC_NAME

#gcloud projects delete $PROJECT_ID -q
