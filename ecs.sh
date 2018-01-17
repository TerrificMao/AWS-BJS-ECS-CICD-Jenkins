#!/bin/bash
#Constants
REGION="cn-north-1"
REPOSITORY_NAME="aws-bjs-ecs-cicd-jenkins"
CLUSTER="AWS-BJS-ECS-CICD-Jenkins"
SERVICE_NAME="aws-ecs-cicd-jenkins-php"
FAMILY="AWS-BJS-ECS-Task-Definition-Name"
NAME="simple-app"
TASKDEFNAME="AWS-BJS-ECS-Task-Definition-Name"
#WORKSPACE=/home/ec2-user/ecs-jenkins-demo

#Store the repositoryUri as a variable
REPOSITORY_URI=`aws ecr describe-repositories --repository-names ${REPOSITORY_NAME} --region ${REGION} | jq .repositories[].repositoryUri | tr -d '"'`

#echo ${REPOSITORY_URI}

#Replace the build number and respository URI placeholders with the constants above. Use "/", ";" or "@" to work as delimiter
sed -e "s;%BUILD_NUMBER%;${BUILD_NUMBER};g" -e "s;%REPOSITORY_URI%;${REPOSITORY_URI};g" taskdef.json > ${NAME}-v_${BUILD_NUMBER}.json

#Register the task definition in the repository
aws ecs register-task-definition --family ${FAMILY} --cli-input-json file://${WORKSPACE}/${NAME}-v_${BUILD_NUMBER}.json --region ${REGION}

#Get the Services information to make sure whether this servuce is exist. If the service is exist, then SERVICES return "" , whereas if is not exist, then SERVICES return "{ "reason": "MISSING", "arn": "........." }"
SERVICES=`aws ecs describe-services --services ${SERVICE_NAME} --cluster ${CLUSTER} --region ${REGION} | jq .failures[]`

#Get latest revision
REVISION=`aws ecs describe-task-definition --task-definition ${TASKDEFNAME} --region ${REGION} | jq .taskDefinition.revision`

#Create or update service
if [ "$SERVICES" == "" ]; then
  echo "entered existing service"
  DESIRED_COUNT=`aws ecs describe-services --services ${SERVICE_NAME} --cluster ${CLUSTER} --region ${REGION} | jq .services[].desiredCount`
  if [ ${DESIRED_COUNT} = "0" ]; then
    DESIRED_COUNT="2"
  fi
  aws ecs update-service --cluster ${CLUSTER} --region ${REGION} --service ${SERVICE_NAME} --task-definition ${FAMILY}:${REVISION} --desired-count ${DESIRED_COUNT}
else
  echo "entered new service"
  aws ecs create-service --service-name ${SERVICE_NAME} --desired-count 2 --task-definition ${FAMILY} --cluster ${CLUSTER} --region ${REGION}
fi