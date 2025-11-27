pipeline {
  agent {
    kubernetes {
      defaultContainer 'jnlp'
      yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
spec:
  priorityClassName: jenkins-agent-high
  containers:
    - name: sonar-scanner
      image: sonarsource/sonar-scanner-cli:latest
      command: ['cat']
      tty: true
      resources:
        requests:
          cpu: "50m"
          memory: "128Mi"
        limits:
          cpu: "200m"
          memory: "256Mi"

    - name: kubectl
      image: bitnami/kubectl:latest
      command: ['cat']
      tty: true
      resources:
        requests:
          cpu: "20m"
          memory: "64Mi"
        limits:
          cpu: "100m"
          memory: "128Mi"
      env:
        - name: KUBECONFIG
          value: /kube/config
      volumeMounts:
        - name: kubeconfig-secret
          mountPath: /kube/config
          subPath: kubeconfig

    - name: kaniko
      image: gcr.io/kaniko-project/executor:latest
      command: ['cat']
      tty: true
      volumeMounts:
        - name: kaniko-secret
          mountPath: /kaniko/.docker
      resources:
        requests:
          cpu: "100m"
          memory: "256Mi"
        limits:
          cpu: "500m"
          memory: "1Gi"

  volumes:
    - name: kubeconfig-secret
      secret:
        secretName: kubeconfig-secret
    - name: kaniko-secret
      secret:
        secretName: docker-registry-creds
"""
    }
  }

  environment {
    IMAGE_NAME        = "ecommerce-frontend"
    IMAGE_TAG         = "v1"
    REGISTRY_URL      = "nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local:8085"
    REGISTRY_REPO     = "ajinkya-project"
    FULL_IMAGE_NAME   = "${REGISTRY_URL}/${REGISTRY_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"

    SONAR_HOST_URL    = "http://my-sonarqube-sonarqube.sonarqube.svc.cluster.local:9000"
    SONAR_PROJECT_KEY = "2401096_ecommerce_website"

    K8S_NAMESPACE     = "2401096"
    K8S_DEPLOYMENT    = "ecommerce-frontend-deployment"
    K8S_MANIFEST_FILE = "ecommerce-frontend-deployment.yaml"
  }

  options {
    // Prevent parallel builds if that leads to too many pods
    disableConcurrentBuilds()
    // Adjust pipeline-level timeout to avoid long agent creation waits:
    timeout(time: 30, unit: 'MINUTES')
  }

  stages {
    stage('Build & Push Image (kaniko)') {
      steps {
        container('kaniko') {
          // Kaniko expects a docker-config at /kaniko/.docker/config.json, which we get from the secret
          sh '''
            echo "Starting kaniko build+push..."
            /kaniko/executor \
              --context ${WORKSPACE} \
              --dockerfile ${WORKSPACE}/Dockerfile \
              --destination ${FULL_IMAGE_NAME} \
              --cache=true
          '''
        }
      }
    }

    stage('SonarQube Analysis') {
      steps {
        container('sonar-scanner') {
          withCredentials([string(credentialsId: 'sonarqube-2401096', variable: 'SONAR_TOKEN')]) {
            sh '''
              echo "Running SonarQube analysis..."
              sonar-scanner \
                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                -Dsonar.host.url=${SONAR_HOST_URL} \
                -Dsonar.login=$SONAR_TOKEN \
                -Dsonar.sources=. \
                -Dsonar.exclusions=node_modules/**,k8s-deployment/**,**/*.png,**/*.jpg,**/*.jpeg,**/*.gif
            '''
          }
        }
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        container('kubectl') {
          script {
            dir('k8s-deployment') {
              sh """
                echo "Updating manifest image to ${FULL_IMAGE_NAME}..."
                # Replace the image placeholder in the manifest before applying
                sed -i 's|image: .*|image: ${FULL_IMAGE_NAME}|g' ${K8S_MANIFEST_FILE} || true

                echo "Applying manifest..."
                kubectl apply -f ${K8S_MANIFEST_FILE} -n ${K8S_NAMESPACE}
                echo "Waiting for rollout..."
                kubectl rollout status deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} --timeout=120s
              """
            }
          }
        }
      }
    }
  }

  post {
    always {
      echo "Pipeline finished with status: ${currentBuild.currentResult}"
    }
    failure {
      echo "Pipeline failed."
    }
  }
}
