pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        AWS_CONFIG_FILE = '/root/.aws/config'
        AWS_SHARED_CREDENTIALS_FILE = '/root/.aws/credentials'
    }
    
    parameters {
        choice(
            name: 'ENV',
            choices: ['dev', 'prod'],
            description: 'Select the environment to deploy'
        )
        choice(
            name: 'ACTION',
            choices: ['apply', 'destroy'],
            description: 'Select action (apply or destroy)'
        )
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: 'Automatically approve all deployment stages'
        )
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Configure kubectl') {
            steps {
                script {
                    sh """
                        aws eks update-kubeconfig --name eks-gpu-${params.ENV} --region ${AWS_REGION}
                    """
                }
            }
        }

       stage('Install ArgoCD') {
            steps {
                script {
                    sh '''
                        # Create ArgoCD namespace
                        kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
                        
                        # Install ArgoCD base components
                        kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
                        
                        # Apply our customizations (only overrides)
                        kubectl apply -f argocd/install/install.yaml
                        
                        # Wait and check pod status
                        echo "Waiting for ArgoCD pods to start..."
                        sleep 30
                        
                        # Verify deployments
                        for deployment in argocd-server argocd-repo-server argocd-redis; do
                            echo "Waiting for deployment $deployment to be ready..."
                            kubectl wait --for=condition=available --timeout=600s deployment/$deployment -n argocd
                        done
                        
                        # Verify statefulset
                        echo "Waiting for application controller statefulset to be ready..."
                        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=600s
                        
                        echo "Final pod status:"
                        kubectl get pods -n argocd
                    '''
                }
            }
        }
        
        stage('Configure ArgoCD') {
            steps {
                script {
                    sh '''
                        # Wait for the initial admin secret to be created
                        echo "Waiting for admin secret to be created..."
                        while ! kubectl -n argocd get secret argocd-initial-admin-secret &> /dev/null; do
                            echo "Waiting for admin secret..."
                            sleep 5
                        done
                        
                        # Get ArgoCD server address
                        echo "Getting ArgoCD server address..."
                        ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                        
                        # Wait for the server to be ready
                        echo "Waiting for ArgoCD server to be ready..."
                        while [ -z "$ARGOCD_SERVER" ]; do
                            sleep 5
                            ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                        done
                        
                        # Get the admin password
                        echo "Getting admin password..."
                        ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
                        
                        # Login to ArgoCD
                        echo "Logging into ArgoCD..."
                        argocd login "$ARGOCD_SERVER" \
                            --username admin \
                            --password "$ADMIN_PASSWORD" \
                            --insecure
                    '''
                }
            }
        }
        
        stage('Deploy Applications') {
            steps {
                script {
                    sh '''
                        # Create project
                        kubectl apply -f argocd/projects/stable-diffusion.yaml
                        
                        # Create application
                        kubectl apply -f argocd/applications/stable-diffusion.yaml
                    '''
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                script {
                    sh """
                        echo "Waiting for ArgoCD to sync changes..."
                        argocd app wait hello-world --timeout 300
                        
                        echo "Waiting for deployment rollout..."
                        kubectl -n stable-diffusion rollout status deployment/hello-world --timeout=300s
                    """
                }
            }
        }
    }
    
    post {
        always {
            sh '''
                rm -f terraform/foundation/tfplan
                rm -f terraform/storage/tfplan
                rm -f terraform/networking/tfplan
                rm -f terraform/compute/tfplan
            '''
        }
        success {
            echo "Pipeline completed successfully!"
        }
        failure {
            echo "Pipeline failed!"
        }
    }
} 