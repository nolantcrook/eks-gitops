pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        AWS_CONFIG_FILE = '/root/.aws/config'
        AWS_SHARED_CREDENTIALS_FILE = '/root/.aws/credentials'
        APPLICATIONS = '{"stable-diffusion": "stable-diffusion"}'
        KUBECONFIG = credentials('kubeconfig')
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
        
        stage('Install External Secrets Operator') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        # Add the External Secrets Operator Helm repository
                        helm repo add external-secrets https://charts.external-secrets.io
                        
                        # Update Helm repositories
                        helm repo update
                        
                        # Check if already installed
                        if helm list -n external-secrets | grep -q "external-secrets"; then
                            echo "External Secrets Operator already installed, upgrading..."
                            helm upgrade external-secrets \
                                external-secrets/external-secrets \
                                --namespace external-secrets \
                                --set installCRDs=true
                        else
                            echo "Installing External Secrets Operator..."
                            # Install the External Secrets Operator
                            helm install external-secrets \
                                external-secrets/external-secrets \
                                --namespace external-secrets \
                                --create-namespace \
                                --set installCRDs=true
                        fi
                        
                        # Wait for the operator to be ready
                        kubectl -n external-secrets wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets --timeout=120s
                    '''
                }
            }
        }
        
        stage('Deploy DeepSeek API') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        # Apply kustomization
                        kubectl apply -k stable-diffusion-gitops/apps/deepseek/base
                        
                        # Wait for the deployment to be ready
                        kubectl -n deepseek wait --for=condition=available deployment/deepseek-deployment --timeout=300s
                    '''
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        # Check if External Secrets are working
                        kubectl -n deepseek get externalsecrets
                        kubectl -n deepseek get secrets
                        
                        # Check if service is accessible
                        kubectl -n deepseek get svc deepseek
                        
                        # Check if pods are running
                        kubectl -n deepseek get pods
                    '''
                }
            }
        }
        
        stage('Configure kubectl') {
            steps {
                script {
                    sh """
                        aws eks update-kubeconfig --name eks-gpu-${params.ENV} --region ${AWS_REGION} || true
                    """
                }
            }
        }

        stage('Install NVIDIA Device Plugin') {
            steps {
                script {
                    sh """
                        echo "Deploying NVIDIA device plugin..."
                        kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.0/deployments/static/nvidia-device-plugin.yml
                    """
                }
            }
        }

        stage('Install ArgoCD') {
            steps {
                script {
                    sh """
                        echo "Installing ArgoCD core components..."
                        kubectl apply -k argocd/overlays/dev
                        
                        # Wait for ArgoCD server to be ready
                        kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
                    """
                    
                    // Get GitHub credentials
                    def (username, token) = sh(
                        script: '''
                            SECRET_JSON=$(aws secretsmanager get-secret-value \
                                --secret-id github/argocd-gitops-secret \
                                --region ${AWS_REGION} \
                                --query SecretString \
                                --output text)
                            
                            if [ $? -ne 0 ]; then
                                echo "Failed to retrieve secret from AWS" >&2
                                exit 1
                            fi
                            
                            echo "$SECRET_JSON" | python3 -c '
import sys, json
try:
    secret = json.load(sys.stdin)
    print(secret["username"])
    print(secret["token"])
except Exception as e:
    print(f"Error parsing secret: {e}", file=sys.stderr)
    sys.exit(1)
'
                        ''',
                        returnStdout: true
                    ).trim().split('\n')
                    
                    if (!username?.trim() || !token?.trim()) {
                        error "Failed to get valid credentials from AWS Secrets Manager"
                    }
                    
                    // Create repository secret
                    sh """
                        kubectl delete secret github-repo -n argocd --ignore-not-found
                        sleep 2
                        
                        kubectl create secret generic github-repo \
                            -n argocd \
                            --from-literal=type=git \
                            --from-literal=url=https://github.com/nolantcrook/stable-diffusion-gitops.git \
                            --from-literal=username='${username}' \
                            --from-literal=password='${token}'
                        
                        kubectl label secret github-repo -n argocd \
                            argocd.argoproj.io/secret-type=repository --overwrite
                    """
                }
            }
        }
        
        stage('Deploy Ingress') {
            steps {
                script {
                    sh """
                        echo "Deploying Ingress components..."
                        kubectl apply -k apps/ingress/overlays/dev
                        
                        # Wait for Ingress controller to be ready
                        kubectl wait --for=condition=available deployment/ingress-nginx-controller -n ingress-nginx --timeout=300s
                    """
                }
            }
        }

        stage('Deploy Autoscaler') {
            steps {
                script {
                    sh """
                        echo "Deploying Cluster Autoscaler..."
                        kubectl apply -k apps/eks-autoscaler/base
                        
                        # Wait for Autoscaler to be ready
                        kubectl wait --for=condition=available deployment/cluster-autoscaler -n kube-system --timeout=300s
                    """
                }
            }
        }
        
        stage('Deploy Applications') {
            steps {
                script {
                    sh '''
                        # Create namespaces
                        echo "${APPLICATIONS}" | python3 -c "
import sys, json
apps = json.load(sys.stdin)
for app_name, namespace in apps.items():
    print(f'{namespace}')
" | sort -u | while read namespace; do
                            kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
                        done

                        # Apply ArgoCD applications
                        kubectl apply -f argocd/applications/
                        
                        # Wait for namespaces
                        echo "${APPLICATIONS}" | python3 -c "
import sys, json
apps = json.load(sys.stdin)
for app_name, namespace in apps.items():
    print(f'{namespace}')
" | sort -u | while read namespace; do
                            kubectl wait --for=jsonpath=.status.phase=Active namespace/$namespace --timeout=30s
                        done
                    '''
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo "Pipeline completed successfully!"
        }
        failure {
            echo "Pipeline failed!"
        }
    }
} 