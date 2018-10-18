#!/bin/bash

if [ "$1" == "--help" ] || [ "$1" == "-h" ]
then
  SCRIPT=`basename $0`
  echo "ENV=Prod $SCRIPT"
  exit 1
fi

USERNAME="drussier" # `echo $USER | tr '_' '-'`
ENV=`echo ${ENV:-Prod} | perl -pE 's/^(.)(.*)$/\U$1\L$2/'`
ENV_MINI=`echo $ENV | tr 'A-Z' 'a-z'`

echo -n "Delete ExploratoryTesting-${ENV_MINI}-${USERNAME}? (y/N) "
read r
if [ "$r" != "y" ]
then
  echo "Aborted ..."
  exit
fi
echo "Deleting fleet ..."

export OGURY_ENVIRONMENT=$ENV
export LAMBDA_ACTION="Delete"
export LAMBDA_FUNCTION=`aws lambda list-functions --region eu-west-1 | jq -r '.Functions[] | select(.FunctionName | contains(env.OGURY_ENVIRONMENT) and contains("ExploratoryTestingStack") and contains(env.LAMBDA_ACTION)) | .FunctionName'`
export LAMBDA_PAYLOAD='{"id":"ExploratoryTesting-'${ENV_MINI}'-'${USERNAME}'"}'
  
LOG=`mktemp`
set -e
aws lambda invoke \
  --invocation-type RequestResponse \
  --function-name $LAMBDA_FUNCTION \
  --region eu-west-1 \
  --log-type Tail \
  --payload "$LAMBDA_PAYLOAD" $LOG | jq -r '.LogResult' | base64 --decode
echo ""
jq . $LOG
