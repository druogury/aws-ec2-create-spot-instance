#!/bin/bash

if [ "$1" == "--help" ] || [ "$1" == "-h" ]
then
  SCRIPT=`basename $0`
  echo "ENV=${ENV:-Prod} SSH_USER=${SSH_USER:-ubuntu} SSH_OPT=$SSH_OPT $SCRIPT"
  exit 1
fi

# USERNAME=`echo $USER | tr '_' '-'`
USERNAME=drussier
ENV=`echo ${ENV:-Prod} | perl -pE 's/^(.)(.*)$/\U$1\L$2/'`
ENV_MINI=`echo $ENV | tr 'A-Z' 'a-z'`
SSH_USER=${SSH_USER:-ubuntu}

echo -en "Finding autoscaling group ...\t"
ASG=`aws cloudformation describe-stack-resources --stack-name=ExploratoryTesting-$ENV_MINI-$USERNAME 2> /dev/null | jq -r '.StackResources[]|select(.LogicalResourceId=="AutoScalingGroup").PhysicalResourceId'`
echo "$ASG"
if [ -z "$ASG" ]
then
  echo "No match"
  exit 1
fi

echo -en "Finding instances ...\t\t"
INSTANCES=($(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG | jq -r '.AutoScalingGroups[].Instances[].InstanceId'))
echo ${INSTANCES[@]}
if [ ${#INSTANCES[@]} == 0 ]
then
  echo "No match"
  exit 1
fi

echo -en "Finding ips ...\t\t\t"
IPS=($(aws ec2 describe-instances --instance-ids ${INSTANCES[@]} | jq -r '.Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddress'))
echo ${IPS[@]}
if [ ${#IPS[@]} == 0 ]
then
  echo "No match"
  exit 1
fi

if [ ${#IPS[@]} == 1 ]
then
  ssh -l $SSH_USER $SSH_OPT ${IPS[@]} $*
else
  csshX -l $SSH_USER ${IPS[@]} $*
  sleep 0.5
  osascript -e 'tell application "Terminal" to activate'
fi
