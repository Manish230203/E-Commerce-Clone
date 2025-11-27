pipeline {
  agent{
     kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: sonar-scanner
    image: sonarsource/sonar-scanner-cli
    command:
    - cat
    tty: true
  - name: kubectl
    image: bitnami/kubectl:latest
    command:
    - cat
    tty: true
    securityContext:
      runAsUser: 0
      readOnlyRootFilesystem: false
    env:
    - name: KUBECONFIG
      value: /kube/config        
    volumeMounts:
    - name: kubeconfig-secret
      mountPath: /kube/config
      subPath: kubeconfig
  - name: dind
    image: docker:dind
    securityContext:
      privileged: true  # Needed to run Docker daemon
    env:
    - name: DOCKER_TLS_CERTDIR
      value: ""  # Disable TLS for simplicity
    volumeMounts:
    - name: docker-config
      mountPath: /etc/docker/daemon.json
      subPath: daemon.json  # Mount the file directly here
  volumes:
  - name: docker-config
    configMap:
      name: docker-daemon-config
  - name: kubeconfig-secret
    secret:
      secretName: kubeconfig-secret
'''
        }
  }

  environment {
    DOCKERHUB_CREDENTIALS = 'dockerhub-cred'
    KUBECONFIG_CREDENTIALS = 'kubeconfig-cred'
    LOCAL_IMAGE = 'e-commerce-clone'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build Docker') {
      steps {
        // All Groovy (def, etc.) must be inside script { }
        script {
          // compute tag in Groovy
          def tag = "${env.BUILD_NUMBER}"

          // run docker commands inside the dind container
          container('dind') {
            // wait for docker daemon
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
            // Build using the Groovy variable (string interpolation)
            sh "docker build -t ${LOCAL_IMAGE}:${tag} ."
            sh "docker tag ${LOCAL_IMAGE}:${tag} ${LOCAL_IMAGE}:latest"
          } // end container('dind')
        } // end script
      } // end steps
    } // end stage

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CREDENTIALS}",
                                          usernameVariable: 'DH_USER',
                                          passwordVariable: 'DH_PASS')]) {
          script {
            def tag = "${env.BUILD_NUMBER}"

            container('dind') {
              // Tag to the credentials' namespace, login and push
              sh "docker tag ${LOCAL_IMAGE}:${tag} ${DH_USER}/${LOCAL_IMAGE}:${tag}"
              // use script: form to avoid insecure interpolation warning
              sh(script: "echo \"$DH_PASS\" | docker login -u \"$DH_USER\" --password-stdin")
              sh "docker push ${DH_USER}/${LOCAL_IMAGE}:${tag}"
              sh "docker tag ${LOCAL_IMAGE}:${tag} ${DH_USER}/${LOCAL_IMAGE}:latest"
              sh "docker push ${DH_USER}/${LOCAL_IMAGE}:latest"
            }
          }
        }
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIALS}", variable: 'KUBECONFIG_FILE')]) {
          script {
            sh 'mkdir -p ~/.kube'
            sh 'cp $KUBECONFIG_FILE ~/.kube/config'
            // use DH_USER from credentials; DH_USER will be available only inside withCredentials
            // sed replacement uses ${env.BUILD_NUMBER} and ${DH_USER}/${LOCAL_IMAGE}
            sh """
              sed -i.bak -E 's|(image:\\s*).+|\\1${env.DH_USER ?: env.DOCKERHUB_USER}/${LOCAL_IMAGE}:${env.BUILD_NUMBER}|' k8s-deployment/deployment.yaml || true
              kubectl apply -f k8s-deployment/
            """
          }
        }
      }
    }
  } // end stages

  post {
    always {
      deleteDir()
    }
    failure {
      echo "Build failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
    }
  }
}
