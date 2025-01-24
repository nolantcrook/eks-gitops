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
    }
    
    stages {
        stage('Configure kubectl') {
            steps {
                script {
                    // Update kubeconfig for the EKS cluster using existing AWS credentials
                    sh """
                        aws eks update-kubeconfig --name eks-gpu --region ${AWS_REGION}
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
        success {
            echo "Deployment to ${params.ENV} completed successfully!"
        }
        failure {
            echo "Deployment to ${params.ENV} failed!"
        }
    }
} 