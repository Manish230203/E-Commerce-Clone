pipeline {
  agent any

  environment {
    DOCKERHUB_CREDENTIALS = 'dockerhub-cred'    // Jenkins credentials id (username/password)
    KUBECONFIG_CREDENTIALS = 'kubeconfig-cred'  // Jenkins credentials id (file containing kubeconfig)
    IMAGE_NAME = 'manish2302/e-commerce-clone'   // update if your Docker Hub username differs
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
          sh "docker --version || true"
          sh "docker build -t ${IMAGE_NAME}:${tag} ."
          sh "docker tag ${IMAGE_NAME}:${tag} ${IMAGE_NAME}:latest"
        }
      }
    }

    stage('Push to Docker Hub') {
      steps {
        // Bind username/password only for this step
        withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CREDENTIALS}",
                                          usernameVariable: 'DH_USER',
                                          passwordVariable: 'DH_PASS')]) {
          sh "echo $DH_PASS | docker login -u $DH_USER --password-stdin"
          sh "docker push ${IMAGE_NAME}:${env.BUILD_NUMBER}"
          sh "docker push ${IMAGE_NAME}:latest"
        }
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        // Bind kubeconfig file only for this step
        withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIALS}", variable: 'KUBECONFIG_FILE')]) {
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
      cleanWs()
    }
    failure {
      echo "Build failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
    }
  }
}
