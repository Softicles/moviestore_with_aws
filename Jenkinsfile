pipeline {
  agent none
  environment {
    AWS_REGION    = 'us-west-2'
    AWS_ACCOUNT   = '119952307500'
    ECR_REPO      = 'movies-web'
    IMAGE_URI     = "${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
    APP_NAME      = 'movies-web'
    CLUSTER       = 'movies-app'         // create this ECS cluster if not present
    SERVICE       = 'movies-web-svc'     // ECS service name
    CONTAINER     = 'web'
    CPU           = '512'
    MEMORY        = '1024'
    PORT          = '8000'
    // Fill these with your subnets/SGs. For ALB, we'll reference a target group.
    PRIVATE_SUBNETS = 'subnet-0a3c78c242c89604b,subnet-0f0c79f51c2ddecd1,subnet-02a4c9563ddc27163,subnet-056f9d8990283c097'
    // Security group that allows outbound & inbound from ALB target group
    SERVICE_SG    = 'sg-sg-0618b0c72a75a39f1'
    // ALB target group ARN for port 8000 (create in step 5)
    TARGET_GROUP_ARN = 'arn:aws:elasticloadbalancing:us-west-2:119952307500:targetgroup/movies-tg/92ab11f847cf227b'
    DESIRED_COUNT = '2'
  }

  stages {
    stage('Build on Fargate agent') {
      agent {
        label 'fargate-agent'
      }
      steps {
        checkout scm

        sh '''
          aws --version
          aws ecr get-login-password --region $AWS_REGION \
            | docker login --username AWS --password-stdin $IMAGE_URI

          GIT_SHA=$(git rev-parse --short=7 HEAD)
          docker build -t $IMAGE_URI:$GIT_SHA -t $IMAGE_URI:latest .
          docker push $IMAGE_URI:$GIT_SHA
          docker push $IMAGE_URI:latest
          echo "IMAGE_TAG=$GIT_SHA" > image_meta.env
        '''
        stash name: 'image_meta', includes: 'image_meta.env'
      }
    }

    stage('Register/Update Task Definition') {
      agent { label 'fargate-agent' }
      steps {
        unstash 'image_meta'
        sh '''
          set -e
          . image_meta.env

          cat > taskdef.json <<EOF
          {
            "family": "${APP_NAME}",
            "networkMode": "awsvpc",
            "requiresCompatibilities": ["FARGATE"],
            "cpu": "${CPU}",
            "memory": "${MEMORY}",
            "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT}:role/ecsTaskExecutionRole",
            "taskRoleArn": "arn:aws:iam::${AWS_ACCOUNT}:role/ecsAppTaskRole",
            "containerDefinitions": [
              {
                "name": "${CONTAINER}",
                "image": "${IMAGE_URI}:${IMAGE_TAG}",
                "portMappings": [{ "containerPort": ${PORT}, "protocol": "tcp" }],
                "essential": true,
                "environment": [
                  { "name": "DJANGO_SETTINGS_MODULE", "value": "movies.settings" },
                  { "name": "PORT", "value": "${PORT}" }
                ],
                "logConfiguration": {
                  "logDriver": "awslogs",
                  "options": {
                    "awslogs-group": "/ecs/${APP_NAME}",
                    "awslogs-region": "${AWS_REGION}",
                    "awslogs-stream-prefix": "ecs"
                  }
                }
              }
            ]
          }
          EOF

          aws ecs register-task-definition \
            --region $AWS_REGION \
            --cli-input-json file://taskdef.json
        '''
      }
    }

    stage('Create/Update Service') {
      agent { label 'fargate-agent' }
      steps {
        sh '''
          set -e
          # Create cluster if it does not exist (no-op if exists)
          aws ecs describe-clusters --clusters $CLUSTER --region $AWS_REGION >/dev/null 2>&1 || true
          aws ecs create-cluster --cluster-name $CLUSTER --region $AWS_REGION >/dev/null 2>&1 || true

          # Determine latest task def
          TD_ARN=$(aws ecs list-task-definitions --family-prefix $APP_NAME --sort DESC --region $AWS_REGION --max-items 1 --query 'taskDefinitionArns[0]' --output text)

          # Try create-service; if exists, update
          set +e
          aws ecs create-service \
            --region $AWS_REGION \
            --cluster $CLUSTER \
            --service-name $SERVICE \
            --task-definition $TD_ARN \
            --desired-count $DESIRED_COUNT \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNETS],securityGroups=[$SERVICE_SG],assignPublicIp=DISABLED}" \
            --load-balancers "targetGroupArn=$TARGET_GROUP_ARN,containerName=$CONTAINER,containerPort=$PORT"
          STATUS=$?
          set -e

          if [ $STATUS -ne 0 ]; then
            aws ecs update-service \
              --region $AWS_REGION \
              --cluster $CLUSTER \
              --service $SERVICE \
              --task-definition $TD_ARN \
              --desired-count $DESIRED_COUNT \
              --force-new-deployment
          fi
        '''
      }
    }
  }

  post {
    always {
      echo 'Pipeline finished.'
    }
  }
}
