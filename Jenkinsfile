pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        AWS_CONFIG_FILE = '/root/.aws/config'
        AWS_SHARED_CREDENTIALS_FILE = '/root/.aws/credentials'
        APPLICATIONS = '{"stable-diffusion": "stable-diffusion"}'
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
