pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
    }
    
    parameters {
        choice(
            name: 'ENV',
            choices: ['dev', 'prod'],
            description: 'Select the environment to deploy'
        )
        string(
            name: 'GIT_BRANCH',
            defaultValue: 'main',
            description: 'Git branch to deploy'
        )
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Update Manifests') {
            steps {
                script {
                    // Clone the GitOps repo if different from current
                    sh """
                        if [ ! -d "apps" ]; then
                            git clone https://github.com/your-org/stable-diffusion-gitops.git .
                        fi
                    """
                    
                    // Commit and push any changes
                    withCredentials([sshUserPrivateKey(credentialsId: 'github-credentials', keyFileVariable: 'SSH_KEY')]) {
                        sh """
                            git config user.email "jenkins@your-company.com"
                            git config user.name "Jenkins"
                            
                            if [[ \$(git status -s) ]]; then
                                git add .
                                git commit -m "Update deployment configuration for ${params.ENV}"
                                GIT_SSH_COMMAND='ssh -i ${SSH_KEY}' git push origin HEAD:${params.GIT_BRANCH}
                            else
                                echo "No changes to commit"
                            fi
                        """
                    }
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                script {
                    // Wait for ArgoCD to sync
                    sh """
                        kubectl config use-context eks-gpu-${params.ENV}
                        
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