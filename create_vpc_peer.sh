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

PROJECT_NAME=gcp-project-1
PROJECT_ID=$PROJECT_NAME-120919
BILLING_ID=$1
VPC_NAME=$PROJECT_NAME-vpc1
PRIVATE_SUBNET=$VPC_NAME-subnet1
NAT_ROUTER=$PROJECT_NAME-nat-router
NAT_GW=$PROJECT_NAME-nat-gw
TEMPLATE=f1-micro-template
INSTANCE_GROUP=$PROJECT_NAME-instance-group
HTTP_HEALTH_CHECK=$PROJECT_NAME-http-health-check
LB_BACKEND_SERVICE=$PROJECT_NAME-lb-backend
URL_MAP=$PROJECT_NAME-url-map
HTTP_PROXY=$PROJECT_NAME-http-proxy
FORWARDING_RULE=$PROJECT_NAME-forwarding-rule

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
if (! gcloud compute networks list | grep $VPC_NAME) then
    gcloud compute networks create $VPC_NAME --subnet-mode=custom
    gcloud compute networks subnets create $PRIVATE_SUBNET \
	    --network=$VPC_NAME \
	    --range=10.0.0.0/24
	    #--region=europe-west3

#### Create ACL rule
    gcloud compute firewall-rules create allow-http-ssh \
	    --network $VPC_NAME \
	    --allow tcp:433,tcp:80,tcp:22,icmp

fi

### Create NAT Router
if (! gcloud compute routers list | grep $NAT_ROUTER) then
    gcloud compute routers create $NAT_ROUTER \
	    --network=$VPC_NAME
fi

### Create NAT GW
if (! gcloud compute routers nats list --router=$NAT_ROUTER | grep $NAT_GW) then
    gcloud compute routers nats create $NAT_GW \
	    --router=$NAT_ROUTER \
	    --auto-allocate-nat-external-ips \
	    --nat-all-subnet-ip-ranges
fi

### Create Instance Template
if (! gcloud compute instance-templates list | grep $TEMPLATE) then
    gcloud compute instance-templates create $TEMPLATE \
	    --machine-type=f1-micro \
	    --image-project=centos-cloud --image=centos-7-v20190916 \
	    --metadata-from-file startup-script=local_db.sh \
	    --network=$VPC_NAME \
	    --subnet=$PRIVATE_SUBNET \
	    --no-address
fi

### Create Managed Instance Group
if (! gcloud compute instance-groups managed list | grep $INSTANCE_GROUP) then
    gcloud compute instance-groups managed create $INSTANCE_GROUP \
	    --size=1 \
	    --template=$TEMPLATE
	    #--zone=europe-west3-a

    gcloud compute instance-groups managed set-named-ports $INSTANCE_GROUP \
	    --named-ports=http:80

    gcloud compute instance-groups managed set-autoscaling $INSTANCE_GROUP \
	    --min-num-replicas=1 \
	    --max-num-replicas=2
	    #--scale-based-on-load-balancing \
	    #--target-load-balancing-utilization=0.1
fi

### Create HTTP LB
### Health check
if (! gcloud compute http-health-checks list | grep $HTTP_HEALTH_CHECK) then
    gcloud compute http-health-checks create $HTTP_HEALTH_CHECK
fi

### Create Backend
if (! gcloud compute backend-services list | grep $LB_BACKEND_SERVICE) then
    gcloud compute backend-services create $LB_BACKEND_SERVICE \
	    --protocol=HTTP \
	    --port-name=http \
	    --http-health-checks=$HTTP_HEALTH_CHECK \
	    --global

    gcloud compute backend-services add-backend $LB_BACKEND_SERVICE \
	    --global \
	    --instance-group=$INSTANCE_GROUP \
	    --instance-group-zone=europe-west3-a

fi

### Create URL Map
if (! gcloud compute url-maps list | grep $URL_MAP) then
    gcloud compute url-maps create $URL_MAP \
	    --default-service=$LB_BACKEND_SERVICE
fi

### Create HTTP Proxy
if (! gcloud compute target-http-proxies list | grep $HTTP_PROXY) then
    gcloud compute target-http-proxies create $HTTP_PROXY \
	    --url-map=$URL_MAP
fi

### Create Forwarding rule
if (! gcloud compute forwarding-rules list | grep $FORWARDING_RULE) then
    gcloud compute forwarding-rules create $FORWARDING_RULE \
	    --global \
	    --target-http-proxy=$HTTP_PROXY \
	    --ports=80
fi

################################################################################
### Second project
################################################################################
PROJECT_NAME=gcp-project-2
PROJECT_ID_V2=$PROJECT_NAME_V2-120919
VPC_NAME_V2=$PROJECT_NAME_V2-vpc1
PRIVATE_SUBNET_V2=$VPC_NAME_V2-subnet1
INSTANCE_NAME_V2=$PROJECT_NAME_V2-instance-f1-micro
INSTANCE_PRIVATE_IP_V2="10.0.2.11"

load_project_2 () {
    gcloud config set project $PROJECT_ID_V2
    gcloud config set compute/region europe-west3
    gcloud config set compute/zone europe-west3-a
}

### Create GCP project
if (! gcloud projects list | grep $PROJECT_NAME_V2) then
    gcloud projects create $PROJECT_ID_V2 --name=$PROJECT_NAME_V2 --set-as-default

### Link billing account id to the project
    gcloud beta billing projects link $PROJECT_ID_V2 \
	    --billing-account $BILLING_ID
fi

load_project_2

### Create VPC
gcloud services enable compute.googleapis.com -q
if (! gcloud compute networks list | grep $VPC_NAME_V2) then
    gcloud compute networks create $VPC_NAME_V2 --subnet-mode=custom
    gcloud compute networks subnets create $PRIVATE_SUBNET_V2 \
	    --network=$VPC_NAME_V2 \
	    --range=10.0.2.0/24

#### Create ACL rule
    gcloud compute firewall-rules create allow-http-ssh-v2 \
	    --network $VPC_NAME_V2 \
	    --allow tcp:433,tcp:80,tcp:22,icmp
fi

### Create Instance
if (! gcloud compute instances list | grep $INSTANCE_NAME_V2) then
    gcloud compute instances create $INSTANCE_NAME_V2 \
	    --machine-type=f1-micro \
	    --image-project=centos-cloud \
	    --image=centos-7-v20190916 \
	    --network=$VPC_NAME_V2 \
	    --subnet=$PRIVATE_SUBNET_V2 \
	    --private-network-ip=$INSTANCE_PRIVATE_IP_V2 \
	    --no-address
fi

################################################################################
#### Create network peering between two VPCs
################################################################################
PEER_NAME=$PROJECT_NAME-peer
PEER_NAME_V2=$PROJECT_NAME_V2-peer

if (! gcloud compute networks peerings list | grep $PEER_NAME_V2) then
    gcloud compute networks peerings create $PEER_NAME_V2 \
	    --network=$VPC_NAME_V2 \
	    --peer-network=$VPC_NAME \
	    --peer-project=$PROJECT_ID \
	    --auto-create-routes
fi

load_project_1

if (! gcloud compute networks peerings list | grep $PEER_NAME) then
    gcloud compute networks peerings create $PEER_NAME \
	    --network=$VPC_NAME \
	    --peer-network=$VPC_NAME_V2 \
	    --peer-project=$PROJECT_ID_V2 \
	    --auto-create-routes
fi

################################################################################
#### Create DNS zone and peering
################################################################################
DNS_ZONE=$PROJECT_NAME-dns-zone
DNS_NAME=dnsname.com
INSTANCE_PRIVATE_IP="10.0.0.2"
DNS_RECORD_NAME=web.$DNS_NAME

### Create DNS zone 
if (! gcloud beta dns managed-zones list | grep $DNS_ZONE) then
    gcloud beta dns managed-zones create $DNS_ZONE \
	    --dns-name=$DNS_NAME. \
	    --description="This is the zone for $DNS_NAME" \
	    --networks=$VPC_NAME \
	    --visibility=private
fi

gcloud beta dns record-sets transaction start --zone=$DNS_ZONE

gcloud beta dns record-sets transaction add \
      --name=$DNS_RECORD_NAME \
      --ttl=1234 \
      --type=A \
      --zone=$DNS_ZONE \
      10.0.0.2

gcloud beta dns record-sets transaction execute --zone=$DNS_ZONE

load_project_2

### Create DNS peering 
gcloud beta dns managed-zones create example-peering-zone \
    --dns-name=$DNS_NAME \
    --description="This is the zone for example.com" \
    --networks=$VPC_NAME_V2 \
    --visibility=private \
    --target-network=$VPC_NAME \
    --target-project=$PROJECT_ID

