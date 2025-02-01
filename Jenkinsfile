pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        AWS_CONFIG_FILE = '/root/.aws/config'
        AWS_SHARED_CREDENTIALS_FILE = '/root/.aws/credentials'
        APPLICATIONS = '{"hello-world": "stable-diffusion"}'
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
                    // Get GitHub credentials from AWS Secrets Manager using Python to parse
                    def (username, token) = sh(
                        script: '''
                            aws secretsmanager get-secret-value \
                                --secret-id github/stable-diff-gitops-secret \
                                --region ${AWS_REGION} \
                                --query SecretString \
                                --output text | \
                            python3 -c "import sys, json
secret = json.load(sys.stdin)
print(secret['username'])
print(secret['token'])"
                        ''',
                        returnStdout: true
                    ).trim().split('\n')
                    
                    // Apply ArgoCD installation with GitHub credentials
                    sh """
                        # Install envsubst
                        apt-get update && apt-get install -y gettext-base
                        
                        # Create ArgoCD namespace
                        kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
                        
                        # Install ArgoCD base components
                        kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
                        
                        # Apply our customizations with GitHub credentials
                        cat argocd/install/core/repo.yaml | \
                        GITHUB_USERNAME='${username}' \
                        GITHUB_TOKEN='${token}' \
                        envsubst | \
                        kubectl apply -f -
                        
                        # Apply remaining configurations
                        kubectl apply -f apps/argocd/base/service.yaml
                        
                        # Wait for pods...
                        echo "Waiting for ArgoCD pods to start..."
                        sleep 30
                        
                        # Verify deployments
                        for deployment in argocd-server argocd-repo-server argocd-redis; do
                            echo "Waiting for deployment \$deployment to be ready..."
                            kubectl wait --for=condition=available --timeout=600s deployment/\$deployment -n argocd
                        done
                        
                        # Verify statefulset
                        echo "Waiting for application controller statefulset to be ready..."
                        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=600s
                        
                        echo "Final pod status:"
                        kubectl get pods -n argocd
                    """
                }
            }
        }
        
        stage('Deploy Applications') {
            steps {
                script {
                    sh '''

                        # Rest of the deployment steps...
                        # Parse APPLICATIONS JSON using Python
                        echo "${APPLICATIONS}" | python3 -c "
import sys, json
apps = json.load(sys.stdin)
for app_name, namespace in apps.items():
    print(f'{namespace}')
" | sort -u | while read namespace; do
                            echo "Creating namespace: $namespace"
                            kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
                        done
                        
                        # Create all ArgoCD projects
                        echo "Applying ArgoCD projects..."
                        kubectl apply -f argocd/projects/
                        
                        # Create all applications
                        echo "Applying ArgoCD applications..."
                        kubectl apply -f argocd/applications/
                        
                        # Wait for namespaces to be ready
                        echo "${APPLICATIONS}" | python3 -c "
import sys, json
apps = json.load(sys.stdin)
for app_name, namespace in apps.items():
    print(f'{namespace}')
" | sort -u | while read namespace; do
                            echo "Waiting for namespace $namespace to be ready..."
                            kubectl wait --for=jsonpath=.status.phase=Active namespace/$namespace --timeout=30s
                        done
                    '''
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