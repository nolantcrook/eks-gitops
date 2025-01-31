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
                        kubectl apply -f argocd/install/core/service.yaml
                        
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
        
        stage('Configure ArgoCD Values') {
            steps {
                script {
                    // Install jq if not present
                    sh 'apt-get update && apt-get install -y jq'
                    
                    // Create environments directory if it doesn't exist
                    sh """
                        mkdir -p argocd/environments/${params.ENV}
                    """
                    
                    // Fetch and configure ArgoCD values
                    sh """
                        # Fetch parameters from AWS
                        PARAMS=\$(aws ssm get-parameter \
                            --name "/eks/${params.ENV}/argocd/ingress" \
                            --with-decryption \
                            --query 'Parameter.Value' \
                            --output text)

                        # Parse JSON and create values file
                        echo "certificate_arn: \$(echo \$PARAMS | jq -r '.certificate_arn')
waf_acl_arn: \$(echo \$PARAMS | jq -r '.waf_acl_arn')
alb_security_group_id: \$(echo \$PARAMS | jq -r '.alb_security_group_id')" > argocd/install/ingress/values.yaml

                        echo "Generated values file:"
                        cat argocd/environments/${params.ENV}/values.yaml
                    """
                }
            }
        }
        
        stage('Deploy Applications') {
            steps {
                script {
                    sh '''
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
        
        stage('Verify Deployment') {
            steps {
                script {
                    sh """
                        # Start port-forward
                        kubectl port-forward svc/argocd-server -n argocd 8085:443 &
                        PF_PID=\$!
                        
                        # Wait for port-forward to establish
                        sleep 5
                        
                        # Try to access ArgoCD server
                        echo "Checking if ArgoCD server is accessible..."
                        max_retries=30
                        count=0
                        while [ \$count -lt \$max_retries ]; do
                            if curl -k -s https://localhost:8085 > /dev/null; then
                                echo "ArgoCD server is up!"
                                break
                            fi
                            echo "Waiting for ArgoCD server... (Attempt \$((count+1))/\$max_retries)"
                            sleep 10
                            count=\$((count+1))
                        done
                        
                        if [ \$count -eq \$max_retries ]; then
                            echo "Failed to connect to ArgoCD server after \$max_retries attempts"
                            exit 1
                        fi
                        
                        # Clean up port-forward
                        if [ ! -z "\$PF_PID" ]; then
                            kill \$PF_PID || true
                        fi
                    """
                    
                    // Parse APPLICATIONS environment variable using Python
                    sh '''
                        echo "${APPLICATIONS}" | python3 -c "
import sys, json, os
apps = json.load(sys.stdin)
for app_name, namespace in apps.items():
    print(f'Checking deployment {app_name} in namespace {namespace}')
    status = os.system(f'kubectl rollout status deployment/{app_name} -n {namespace} --timeout=300s')
    if status != 0:
        sys.exit(1)
"
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