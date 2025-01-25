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
        
        stage('Configure ArgoCD') {
            steps {
                script {
                    // Get the ALB DNS name from terraform output
                    dir('terraform/compute') {
                        withEnv(["ENV=${params.ENV}"]) {
                            sh '''
                                // terragrunt init --terragrunt-non-interactive
                                ARGOCD_SERVER=http://argocd-alb-dev-1516537476.us-west-2.elb.amazonaws.com/
                                
                                # Configure ArgoCD CLI
                                argocd login $ARGOCD_SERVER \
                                    --username admin \
                                    --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) \
                                    --insecure
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Configure kubectl') {
            steps {
                script {
                    // Update kubeconfig for the EKS cluster using existing AWS credentials
                    sh """
                        aws eks update-kubeconfig --name eks-gpu-${ENV} --region ${AWS_REGION}
                    """
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