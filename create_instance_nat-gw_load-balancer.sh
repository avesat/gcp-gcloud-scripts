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
TEMPLATE=f1-micro-template
INSTANCE_GROUP=$PROJECT_NAME-instance-group
HTTP_HEALTH_CHECK=$PROJECT_NAME-http-health-check
LB_BACKEND_SERVICE=$PROJECT_NAME-lb-backend
URL_MAP=$PROJECT_NAME-url-map
HTTP_PROXY=$PROJECT_NAME-http-proxy
FORWARDING_RULE=$PROJECT_NAME-forwarding-rule

### Create GCP project
if (! gcloud projects list | grep $PROJECT_NAME) then
   gcloud projects create $PROJECT_ID --name=$PROJECT_NAME --set-as-default
fi

gcloud config set project $PROJECT_ID
gcloud config set compute/region europe-west3
gcloud config set compute/zone europe-west3-a

### Link billing account id to the project
gcloud beta billing projects link $PROJECT_ID \
	--billing-account $BILLING_ID

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
	    --allow tcp:433,tcp:80,tcp:22

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

#gcloud projects delete $PROJECT_ID -q
