pipeline {
  agent {
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
      privileged: true
    env:
    - name: DOCKER_TLS_CERTDIR
      value: ""
    volumeMounts:
    - name: docker-config
      mountPath: /etc/docker/daemon.json
      subPath: daemon.json
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
    DOCKERHUB_CREDENTIALS = 'dockerhub-cred'   // Jenkins username/password credential ID
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
        script {
          def tag = "${env.BUILD_NUMBER}"
          container('dind') {
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
        // Use Jenkins username/password credential; available only inside withCredentials
        withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CREDENTIALS}",
                                          usernameVariable: 'DH_USER',
                                          passwordVariable: 'DH_PASS')]) {
          script {
            def tag = "${env.BUILD_NUMBER}"
            container('dind') {
              // Tag to DockerHub namespace and push
              sh "docker tag ${LOCAL_IMAGE}:${tag} ${DH_USER}/${LOCAL_IMAGE}:${tag}"
              // avoid insecure interpolation: pass password to stdin
              sh(script: "echo \"$DH_PASS\" | docker login -u \"$DH_USER\" --password-stdin")
              sh "docker push ${DH_USER}/${LOCAL_IMAGE}:${tag}"
              sh "docker tag ${LOCAL_IMAGE}:${tag} ${DH_USER}/${LOCAL_IMAGE}:latest"
              sh "docker push ${DH_USER}/${LOCAL_IMAGE}:latest"
              // write pushed image name to a file for use later if desired
              sh "echo ${DH_USER}/${LOCAL_IMAGE}:latest > pushed-image.txt"
            }
          }
        }
      }
    }

    stage('SonarQube Analysis') {
      steps {
        container('sonar-scanner') {
          withCredentials([string(credentialsId: 'sonar-token-2401199', variable: 'SONAR_TOKEN')]) {
            sh '''
              sonar-scanner \
                -Dsonar.projectKey=2401199_attendance-system \
                -Dsonar.host.url=http://my-sonarqube-sonarqube.sonarqube.svc.cluster.local:9000 \
                -Dsonar.login=$SONAR_TOKEN \
                -Dsonar.python.coverage.reportPaths=coverage.xml
            '''
          }
        }
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        // We need DH_USER to know the image name — reuse same Jenkins credential
        withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CREDENTIALS}",
                                          usernameVariable: 'DH_USER',
                                          passwordVariable: 'DH_PASS')]) {
          script {
            // image to deploy
            def imageToDeploy = "${env.DH_USER}/${LOCAL_IMAGE}:latest"
            container('kubectl') {
              // kubeconfig is already mounted at /kube/config in the kubectl container
              // apply manifests (adjust filenames/paths as needed)
              sh """
                # if you prefer to update image via kubectl set image (safer than sed in-place)
                kubectl -n 2401199 set image deployment/your-deployment-name your-container-name=${imageToDeploy} || true

                # apply manifests in the k8s-deployment directory (if they contain the correct image or are image-agnostic)
                kubectl apply -f k8s-deployment/ || true

                # wait for rollout (change deployment name accordingly)
                kubectl -n 2401199 rollout status deployment/your-deployment-name --timeout=120s || true
              """
            }
          }
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
