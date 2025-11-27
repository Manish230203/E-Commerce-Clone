pipeline {
  agent any

  environment {
    DOCKERHUB_CREDENTIALS = 'dockerhub-cred'    // credentials id in Jenkins
    KUBECONFIG_CREDENTIALS = 'kubeconfig-cred'  // file credential id in Jenkins
    LOCAL_IMAGE = 'e-commerce-clone'            // local build name (must be quoted)
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
          container('dind') {
            // wait for dockerd to be ready
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
            sh "docker build -t ${LOCAL_IMAGE}:${tag} ."
            sh "docker tag ${LOCAL_IMAGE}:${tag} ${LOCAL_IMAGE}:latest"
          }
        }
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CREDENTIALS}",
                                          usernameVariable: 'DH_USER',
                                          passwordVariable: 'DH_PASS')]) {
          container('dind') {
            def tag = "${env.BUILD_NUMBER}"
            // Tag using credentials' username namespace
            sh "docker tag ${LOCAL_IMAGE}:${tag} ${DH_USER}/${LOCAL_IMAGE}:${tag}"
            sh(script: "echo \"$DH_PASS\" | docker login -u \"$DH_USER\" --password-stdin")
            sh "docker push ${DH_USER}/${LOCAL_IMAGE}:${tag}"
            sh "docker tag ${LOCAL_IMAGE}:${tag} ${DH_USER}/${LOCAL_IMAGE}:latest"
            sh "docker push ${DH_USER}/${LOCAL_IMAGE}:latest"
          }
        }
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIALS}", variable: 'KUBECONFIG_FILE')]) {
          sh 'mkdir -p ~/.kube'
          sh 'cp $KUBECONFIG_FILE ~/.kube/config'
          sh """
            sed -i.bak -E 's|(image:\\s*).+|\\1${DH_USER}/${LOCAL_IMAGE}:${env.BUILD_NUMBER}|' k8s-deployment/deployment.yaml || true
            kubectl apply -f k8s-deployment/
          """
        }
      }
    }
  }

  post {
    always {
      deleteDir()
    }
    failure {
      echo "Build failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
    }
  }
}
