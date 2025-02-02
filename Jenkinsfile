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
                    // Get GitHub credentials from AWS Secrets Manager
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
                    
                    // Debug output (redacted for security)
                    echo "Creating secret with username: ${username}"
                    echo "Token length: ${token.length()}"
                    
                    // Create secret directly without using envsubst
                    sh """
                        kubectl delete secret github-repo -n argocd --ignore-not-found
                        kubectl create secret generic github-repo \
                            -n argocd \
                            --from-literal=type=git \
                            --from-literal=url=https://github.com/roguewavefunction/stable-diffusion-gitops.git \
                            --from-literal=username='${username}' \
                            --from-literal=password='${token}'

                        # Add the ArgoCD repository label
                        kubectl label secret github-repo -n argocd \
                            argocd.argoproj.io/secret-type=repository

                        # Verify the secret
                        echo "Secret created:"
                        kubectl get secret github-repo -n argocd
                    """

                    // Restart ArgoCD to pick up new credentials
                    sh """
                        kubectl rollout restart deployment argocd-server -n argocd
                        kubectl rollout status deployment argocd-server -n argocd
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