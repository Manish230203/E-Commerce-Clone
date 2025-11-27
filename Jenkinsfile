pipeline {
  agent any

  environment {
    DOCKERHUB_CREDENTIALS = 'dockerhub-cred'
    KUBECONFIG_CREDENTIALS = 'kubeconfig-cred'
    IMAGE_NAME = 'manish2302/e-commerce-clone'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build Docker') {
      steps {
        script {
          def tag = "${env.BUILD_NUMBER}"

          // Run docker commands inside the sidecar 'dind' container where dockerd/docker CLI exist
          container('dind') {
            // wait for dockerd to be ready (simple loop)
            sh '''
              set -e
              attempt=0
              until docker info >/dev/null 2>&1 || [ $attempt -ge 15 ]; do
                echo "Waiting for dockerd..."
                sleep 2
                attempt=$((attempt+1))
              done
              if ! docker info >/dev/null 2>&1; then
                echo "dockerd did not start"
                exit 1
              fi
            '''

            sh "docker --version"
            sh "docker build -t ${ecommerce-frontend}:${v1} ."
            sh "docker tag ${ecommerce-frontend}:${v1} ${ecommerce-frontend}:latest"
          }
        }
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CREDENTIALS}",
                                        usernameVariable: 'manish2302',
                                        passwordVariable: 'Manish@2302')]) {
          // run docker login & push inside dind as well
          container('dind') {
            // login
            sh "echo \"$DH_PASS\" | docker login -u \"$DH_USER\" --password-stdin"
            sh "docker push ${ecommerce-frontend}:${env.BUILD_NUMBER}"
            sh "docker push ${ecommerce-frontend}:latest"
          }
        }
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIALS}", variable: 'KUBECONFIG_FILE')]) {
          // kubectl should be available in the jnlp agent; if not, you can create a container with kubectl and wrap in container('kubectl') { ... }
          sh 'mkdir -p ~/.kube'
          sh 'cp $KUBECONFIG_FILE ~/.kube/config'
          sh """
            sed -i.bak -E 's|(image:\\s*).+|\\1${IMAGE_NAME}:${env.BUILD_NUMBER}|' k8s-deployment/deployment.yaml || true
            kubectl apply -f k8s-deployment/
          """
        }
      }
    }
  }

  post {
    always {
      // cleanWs() unavailable in your environment; use deleteDir() which is present
      deleteDir()
    }
    failure {
      echo "Build failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
    }
  }
}
