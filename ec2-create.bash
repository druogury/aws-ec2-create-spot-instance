#!/bin/bash

if [ "$1" == "--help" ] || [ "$1" == "-h" ]
then
  SCRIPT=`basename $0`
  echo "ENV=Prod AMI=ami-0c8aaa6a INSTANCE=r3.4xlarge CAPACITY=1 VOLSIZE=120 TRIBE=Algo SQUAD=Algo $SCRIPT"
  echo "Above is the default. You can override only one var :"
  echo "   CAPACITY=2 $SCRIPT"
  exit 1
fi

#USERNAME=${USERNAME:-$(echo $USER | tr '_' '-')}
USERNAME=drussier
ENV=`echo ${ENV:-Prod} | perl -pE 's/^(.)(.*)$/\U$1\L$2/'`
ENV_MINI=`echo $ENV | tr 'A-Z' 'a-z'`
AMI=${AMI:-ami-0c8aaa6a}
INSTANCE=${INSTANCE:-r3.4xlarge}
CAPACITY=${CAPACITY:-1}
VOLSIZE=${VOLSIZE:-120}
TRIBE=${TRIBE:-Algo}
SQUAD=${SQUAD:-Algo}
PRICE=${PRICE:-2.0} #1.0}
JSON=`mktemp`
cat << __EOF__ > $JSON
{
  "id": "ExploratoryTesting-${ENV_MINI}-${USERNAME}",
  "imageId": "${AMI}",
  "instanceType": "${INSTANCE}",
  "desiredCapacity": "${CAPACITY}",
  "volumeSize": "${VOLSIZE}",
  "spotPrice": "${PRICE}",
  "projectName": "exploratorytesting",
  "organizationName": "ogury",
  "roleName": "testing",
  "tribeTag": "${TRIBE}",
  "squadTag": "${SQUAD}"
}
__EOF__

if [[ "${VOLSIZE}" == "0" ]]
then
  sed -i '/volumeSize/d' ${JSON}
fi

jq -S . $JSON
echo -n "Is it correct ? (y/N) "
read r
if [ "$r" != "y" ]
then
  echo "Aborted ..."
  exit
fi
echo "Creating fleet ..."

set -e
export OGURY_ENVIRONMENT=$ENV
export LAMBDA_ACTION="Create"
export LAMBDA_FUNCTION=`aws lambda list-functions --region eu-west-1 | jq -r '.Functions[] | select(.FunctionName | contains(env.OGURY_ENVIRONMENT) and contains("ExploratoryTestingStack") and contains(env.LAMBDA_ACTION)) | .FunctionName'`
aws lambda invoke \
  --invocation-type RequestResponse \
  --function-name $LAMBDA_FUNCTION \
  --region eu-west-1 \
  --log-type Tail \
  --payload file://$JSON \
  ${JSON}.log  | jq -r '.LogResult' | base64 --decode
URL=`jq -r .stack_url ${JSON}.log`
if [ "$URL" != "null" ]
then
  echo ""
  echo "Stack URL: $URL"
  open "$URL"
fi
