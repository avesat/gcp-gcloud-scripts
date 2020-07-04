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
PRIVATE_SUBNET=$VPC_NAME-subnet1
NAT_ROUTER=$PROJECT_NAME-nat-router
NAT_GW=$PROJECT_NAME-nat-gw


load_project_1 () {
    gcloud config set project $PROJECT_ID
    gcloud config set compute/region europe-west3
    gcloud config set compute/zone europe-west3-a
}

################################################################################
#### Create GCP project
################################################################################
if (! gcloud projects list | grep $PROJECT_NAME) then
   gcloud projects create $PROJECT_ID --name=$PROJECT_NAME --set-as-default


### Link billing account id to the project
gcloud beta billing projects link $PROJECT_ID \
	--billing-account $BILLING_ID
fi

load_project_1

################################################################################
#### Create VPC
################################################################################
gcloud services enable compute.googleapis.com -q
if (! gcloud compute networks list | grep $VPC_NAME) then
    gcloud compute networks create $VPC_NAME --subnet-mode=custom
    gcloud compute networks subnets create $PRIVATE_SUBNET \
	    --network=$VPC_NAME \
	    --range=10.0.0.0/24

#### Create ACL rule
    gcloud compute firewall-rules create allow-http-ssh \
	    --network $VPC_NAME \
	    --allow tcp:433,tcp:80,tcp:22,icmp
fi

gcloud services enable containerregistry.googleapis.com -q
gcloud auth configure-docker -q

################################################################################
#### Register docker image
################################################################################
#docker build -t hello-world .
#docker tag hello-world eu.gcr.io/gcp-project-120919/hello-world
#docker push eu.gcr.io/gcp-project-120919/hello-world

################################################################################
#### Connect to the cluster
################################################################################
#gcloud container clusters get-credentials standard-cluster-1 --zone europe-west3-a --project gcp-project-120919

################################################################################
#### Add deployment
################################################################################
#kubectl apply -f deployment.yaml

################################################################################
#### Add service 
################################################################################
#kubectl expose deployment hello-world-deployment --type=LoadBalancer

