```groovy
push:
branches: [ main, dev ]
pull_request:
branches: [ main, dev ]


jobs:
build-and-deploy:
runs-on: ubuntu-latest


steps:
- name: Checkout
uses: actions/checkout@v4


- name: Set up Docker Buildx
uses: docker/setup-buildx-action@v2


- name: Log in to Docker Hub
uses: docker/login-action@v2
with:
username: ${{ secrets.DOCKERHUB_USERNAME }}
password: ${{ secrets.DOCKERHUB_TOKEN }}


- name: Build and push
uses: docker/build-push-action@v4
with:
context: .
push: true
tags: |
${{ secrets.DOCKERHUB_USERNAME }}/e-commerce-clone:latest
${{ secrets.DOCKERHUB_USERNAME }}/e-commerce-clone:${{ github.run_number }}


- name: Deploy to Kubernetes
if: github.ref == 'refs/heads/main'
uses: appleboy/k8s-action@v0.1.1
with:
kubeconfig: ${{ secrets.KUBE_CONFIG }}
manifests: |
k8s-deployment/deployment.yaml
k8s-deployment/service.yaml
```