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
      command: ["cat"]
      tty: true

    - name: kubectl
      image: bitnami/kubectl:latest
      command: ["cat"]
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
      args: ["--registry-mirror=https://mirror.gcr.io", "--storage-driver=overlay2"]
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
        // ----- Docker / Image -----
        IMAGE_NAME        = "ecommerce-frontend"
        IMAGE_TAG         = "v1"
        REGISTRY_URL      = "nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local:8085"
        REGISTRY_REPO     = "ajinkya-project"
        FULL_IMAGE_NAME   = "${REGISTRY_URL}/${REGISTRY_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"

        // ----- SonarQube -----
        SONAR_HOST_URL    = "http://my-sonarqube-sonarqube.sonarqube.svc.cluster.local:9000"
        SONAR_PROJECT_KEY = "2401096_ecommerce_website"

        // ----- Kubernetes -----
        K8S_NAMESPACE     = "2401096"
        K8S_DEPLOYMENT    = "ecommerce-frontend-deployment"
        K8S_MANIFEST_FILE = "ecommerce-frontend-deployment.yaml"
    }

    stages {

        stage('Build Docker Image') {
            steps {
                container('dind') {
                    sh '''
                      sleep 15
                      echo "Building Docker image for E-commerce frontend..."
                      docker build -t ${IMAGE_NAME}:latest .
                      docker image ls
                    '''
                }
            }
        }

        // (Optional) You can add a test stage if you ever add tests (npm, etc.)

        stage('SonarQube Analysis') {
            steps {
                container('sonar-scanner') {
                    withCredentials([string(credentialsId: 'sonarqube-2401096', variable: 'SONAR_TOKEN')]) {
                        sh '''
                          echo "Running SonarQube analysis for E-commerce project..."
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

        stage('Login to Docker Registry') {
            steps {
                container('dind') {
                    sh 'docker --version'
                    sh 'sleep 10'
                    withCredentials([usernamePassword(credentialsId: 'docker-registry-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh '''
                          echo "Logging into Docker registry..."
                          echo "$DOCKER_PASS" | docker login ${REGISTRY_URL} \
                            --username "$DOCKER_USER" \
                            --password-stdin
                        '''
                    }
                }
            }
        }

        stage('Build - Tag - Push') {
            steps {
                container('dind') {
                    sh '''
                      echo "Tagging image as ${FULL_IMAGE_NAME}..."
                      docker tag ${IMAGE_NAME}:latest ${FULL_IMAGE_NAME}

                      echo "Pushing image to registry..."
                      docker push ${FULL_IMAGE_NAME}

                      echo "Verifying pushed image..."
                      docker pull ${FULL_IMAGE_NAME}
                      docker image ls
                    '''
                }
            }
        }

        stage('Deploy E-commerce App') {
            steps {
                container('kubectl') {
                    script {
                        dir('k8s-deployment') {
                            sh """
                              echo "Applying Kubernetes manifest ${K8S_MANIFEST_FILE} in namespace ${K8S_NAMESPACE}..."
                              kubectl apply -f ${K8S_MANIFEST_FILE} -n ${K8S_NAMESPACE}

                              echo "Waiting for deployment rollout..."
                              kubectl rollout status deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE}
                            """
                        }
                    }
                }
            }
        }
    }
}
