#!/bin/bash

create_cloudformation_stack () {
  echo "Creating the needed cloudformation role"
  roleName="stc-consumer-link-cloudformation-role-${ENVIRONMENT_TYPE}"
  roleArn=$(aws --profile="${AWS_CLI_PROFILE}" iam create-role --role-name $roleName --assume-role-policy-document "${ROLE_TRUST_POLICY_FILE}" --output text --query 'Role.Arn')
  
  if [ -z "${roleArn}" ]; then
    echo "Error while creating the role"
    exit 1;
  fi

  echo "The $roleName role arn is: $roleArn"
  echo "Embed the permissions policy to the role to specify what it is allowed to do"
  aws --profile="${AWS_CLI_PROFILE}" iam put-role-policy \
  --role-name "$roleName" \
  --policy-name "stc-consumer-link-cloudformation-policy-${ENVIRONMENT_TYPE}" \
  --policy-document "${ROLE_POLICY_FILE}"

  echo "waiting 10s so that cloudformation recognizes the newly created role"
  sleep 10

  echo "Creating the cloudformation consumer-link API stack and change set"
  stackId=$(aws --profile="${AWS_CLI_PROFILE}" cloudformation create-change-set \
  --stack-name "stc-consumer-link-api-${ENVIRONMENT_TYPE}" \
  --template-body "${API_STACK_TEMPLATE}" \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --role-arn "$roleArn" \
  --change-set-name "stc-consumer-link-api-${ENVIRONMENT_TYPE}-changeset" \
  --change-set-type CREATE \
  --output text --query 'StackId')

  if [ -z "${stackId}" ]; then
    echo "Error while creating the consumer-link API stack"
    exit 1;
  fi

  echo "Cloudformation stc-consumer-link-api-${ENVIRONMENT_TYPE} stack created with the id $stackId"


  echo "Creating the cloudformation pipeline stack and change set"

  pipelineChangeSetId=$(aws --profile="${AWS_CLI_PROFILE}" cloudformation create-change-set \
  --stack-name "stc-consumer-link-pipeline-${ENVIRONMENT_TYPE}" \
  --template-body "${PIPELINE_STACK_TEMPLATE}" \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --parameters ParameterKey="EnvironmentType",ParameterValue="${ENVIRONMENT_TYPE}" ParameterKey="PipelineConnectionArn",ParameterValue="${PIPELINE_CONNECTION_ARN}" ParameterKey="RepositoryId",ParameterValue="${REPOSITORY_ID}" ParameterKey="RepositoryBranch",ParameterValue="${REPOSITORY_BRANCH}" ParameterKey="EnvironmentType",ParameterValue="${ENVIRONMENT_TYPE}" ParameterKey="S3STCAuthBucket",ParameterValue="stc-consumer-link-${ENVIRONMENT_TYPE}-artifacts" ParameterKey="CFAPIConsumerLinkRole",ParameterValue="$roleArn" \
  --role-arn "$roleArn" \
  --change-set-name "stc-consumer-link-pipeline-${ENVIRONMENT_TYPE}-changeset" \
  --change-set-type CREATE \
  --output text --query 'Id')

  if [ -z "${pipelineChangeSetId}" ]; then
    echo "Error while creating the consumer-link pipeline stack"
    exit 1;
  fi


  echo "Cloudformation stc-consumer-link-pipeline-${ENVIRONMENT_TYPE} stack created with the changeSet $pipelineChangeSetId"

  # It will poll every 30 seconds until a successful state has been reached
  echo "Waiting for changeSet to be in status CREATE_COMPLETE"

  aws --profile="${AWS_CLI_PROFILE}" cloudformation wait change-set-create-complete --change-set-name "$pipelineChangeSetId"

  echo "Executing the change set of the stc-consumer-link-pipeline-${ENVIRONMENT_TYPE} stack"

  aws --profile="${AWS_CLI_PROFILE}" cloudformation execute-change-set --change-set-name "$pipelineChangeSetId"

  # It will poll every 30 seconds until a successful state has been reached
  echo "Waiting for changeSet to be executed"

  aws --profile="${AWS_CLI_PROFILE}" cloudformation wait stack-create-complete --stack-name "stc-consumer-link-pipeline-${ENVIRONMENT_TYPE}"
  
  echo "Change set execute completed"
}


main(){
  create_cloudformation_stack
}

main "$@"