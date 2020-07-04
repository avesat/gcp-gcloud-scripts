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

################################################################################
### VM network
################################################################################
PROJECT_NAME=gcp-project
PROJECT_ID=$PROJECT_NAME-120919
BILLING_ID=$1
VPC_VM_NAME=$PROJECT_NAME-vpc-vm
PRIVATE_SUBNET_VM_NAME=$VPC_VM_NAME-subnet-vm
VPC_PRIVATE_SUBNET_VM="192.168.1.0/24"
NAT_ROUTER=$PROJECT_NAME-nat-router
NAT_GW=$PROJECT_NAME-nat-gw
INSTANCE_NAME=$PROJECT_NAME-instance
INSTANCE_PRIVATE_IP="192.168.1.10"

load_project_1 () {
    gcloud config set project $PROJECT_ID
    gcloud config set compute/region europe-west3
    gcloud config set compute/zone europe-west3-a
}
### Create GCP project
if (! gcloud projects list | grep $PROJECT_NAME) then
   gcloud projects create $PROJECT_ID --name=$PROJECT_NAME --set-as-default


### Link billing account id to the project
gcloud beta billing projects link $PROJECT_ID \
	--billing-account $BILLING_ID
fi

load_project_1

### Create VPC
gcloud services enable compute.googleapis.com -q
if (! gcloud compute networks list | grep $VPC_VM_NAME) then
    gcloud compute networks create $VPC_VM_NAME --subnet-mode=custom
    gcloud compute networks subnets create $PRIVATE_SUBNET_VM_NAME \
	    --enable-private-ip-google-access \
	    --network=$VPC_VM_NAME \
	    --range=$VPC_PRIVATE_SUBNET_VM

#### Create ACL rule
    gcloud compute firewall-rules create allow-http-ssh \
	    --network $VPC_VM_NAME \
	    --allow tcp:433,tcp:80,tcp:22,icmp

fi

#### Create NAT Router
#if (! gcloud compute routers list | grep $NAT_ROUTER) then
#    gcloud compute routers create $NAT_ROUTER \
#	    --network=$VPC_VM_NAME
#fi
#
#### Create NAT GW
#if (! gcloud compute routers nats list --router=$NAT_ROUTER | grep $NAT_GW) then
#    gcloud compute routers nats create $NAT_GW \
#	    --router=$NAT_ROUTER \
#	    --auto-allocate-nat-external-ips \
#	    --nat-all-subnet-ip-ranges
#fi

################################################################################
### DB network
################################################################################
VPC_DB_NAME=vpcdb
PRIVATE_SUBNET_DB_NAME=$VPC_DB_NAME-subnet-db
VPC_PRIVATE_SUBNET_DB="192.168.2.0/24"
NAT_DB_ROUTER=$PROJECT_NAME-nat-db-router
NAT_DB_GW=$PROJECT_NAME-nat-db-gw

### Create VPC
if (! gcloud compute networks list | grep $VPC_DB_NAME) then
    gcloud compute networks create $VPC_DB_NAME --subnet-mode=custom
    gcloud compute networks subnets create $PRIVATE_SUBNET_DB_NAME \
	    --enable-private-ip-google-access \
	    --network=$VPC_DB_NAME \
	    --range=$VPC_PRIVATE_SUBNET_DB

#### Create ACL rule
    gcloud compute firewall-rules create allow-db-http-ssh \
	    --network $VPC_DB_NAME \
	    --allow tcp:433,tcp:80,tcp:22,icmp

fi

#### Create NAT Router
#if (! gcloud compute routers list | grep $NAT_DB_ROUTER) then
#    gcloud compute routers create $NAT_DB_ROUTER \
#	    --network=$VPC_DB_NAME
#fi
#
#### Create NAT GW
#if (! gcloud compute routers nats list --router=$NAT_DB_ROUTER | grep $NAT_DB_GW) then
#    gcloud compute routers nats create $NAT_DB_GW \
#	    --router=$NAT_DB_ROUTER \
#	    --auto-allocate-nat-external-ips \
#	    --nat-all-subnet-ip-ranges
#fi

################################################################################
#### Create network peering between two VPCs
################################################################################
#PEER_VM_NAME=$VPC_VM_NAME-peer
#PEER_DB_NAME=$VPC_DB_NAME-peer
#
#if (! gcloud compute networks peerings list | grep $PEER_DB_NAME) then
#    gcloud compute networks peerings create $PEER_DB_NAME \
#	    --network=$VPC_DB_NAME \
#	    --peer-network=$VPC_VM_NAME \
#	    --peer-project=$PROJECT_ID \
#	    --auto-create-routes
#fi
#
#if (! gcloud compute networks peerings list | grep $PEER_VM_NAME) then
#    gcloud compute networks peerings create $PEER_VM_NAME \
#	    --network=$VPC_VM_NAME \
#	    --peer-network=$VPC_DB_NAME \
#	    --peer-project=$PROJECT_ID \
#	    --auto-create-routes
#fi

################################################################################
### VM
################################################################################
### Create Instance
#if (! gcloud compute instances list | grep $INSTANCE_NAME) then
#    gcloud compute instances create $INSTANCE_NAME \
#	    --machine-type=f1-micro \
#	    --image-project=centos-cloud \
#	    --image=centos-7-v20190916 \
#	    --metadata-from-file startup-script=local_postgres_db.sh \
#	    --network=$VPC_NAME \
#	    --subnet=$PRIVATE_SUBNET_VM_NAME \
#	    --private-network-ip=$INSTANCE_PRIVATE_IP
#fi

################################################################################
#### Create DB
################################################################################
POSTGRES_INSTANCE_NAME=postgres7
POSTGRES_SRC_IP="192.168.1.10"

gcloud services enable servicenetworking.googleapis.com -q

if (! gcloud beta sql instances list | grep $POSTGRES_INSTANCE_NAME) then
    gcloud beta sql instances create ${POSTGRES_INSTANCE_NAME} \
	    --region=europe-west3 \
	    --database-version="POSTGRES_9_6" \
	    --tier=db-f1-micro \
	    --network=$VPC_DB_NAME
	    #--zone=europe-west3-a \
	    #--no-require-ssl \
	    #--authorized-networks="0.0.0.0/0"
	    #--no-assign-ip \
	    #--source-ip-address=$POSTGRES_SRC_IP \
fi













