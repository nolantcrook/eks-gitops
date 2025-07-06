#!/bin/bash

# Hauliday Equipment Rentals Deployment Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Help function
show_help() {
    echo "Hauliday Equipment Rentals Deployment Script"
    echo ""
    echo "Usage: $0 [ENVIRONMENT] [OPTIONS]"
    echo ""
    echo "ENVIRONMENTS:"
    echo "  dev     Deploy to development environment"
    echo "  prod    Deploy to production environment"
    echo ""
    echo "OPTIONS:"
    echo "  --build     Build and push Docker image before deploying"
    echo "  --verify    Verify deployment after applying manifests"
    echo "  --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 dev --build --verify"
    echo "  $0 prod --verify"
    echo ""
}

# Default values
ENVIRONMENT=""
BUILD_IMAGE=false
VERIFY_DEPLOYMENT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        dev|prod)
            ENVIRONMENT="$1"
            shift
            ;;
        --build)
            BUILD_IMAGE=true
            shift
            ;;
        --verify)
            VERIFY_DEPLOYMENT=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate environment
if [[ -z "$ENVIRONMENT" ]]; then
    print_error "Environment not specified. Use 'dev' or 'prod'."
    show_help
    exit 1
fi

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
    print_error "Invalid environment: $ENVIRONMENT. Use 'dev' or 'prod'."
    exit 1
fi

print_status "Starting Hauliday deployment to $ENVIRONMENT environment..."

# Build and push image if requested
if [[ "$BUILD_IMAGE" == true ]]; then
    print_status "Building and pushing Docker image..."
    
    if [[ ! -f "/Users/nolancrook/code/api_docker/hauliday/build-frontend.sh" ]]; then
        print_error "Build script not found at /Users/nolancrook/code/api_docker/hauliday/build-frontend.sh"
        exit 1
    fi
    
    cd /Users/nolancrook/code/api_docker/hauliday
    ./build-frontend.sh
    
    if [[ $? -eq 0 ]]; then
        print_success "Docker image built and pushed successfully"
    else
        print_error "Failed to build and push Docker image"
        exit 1
    fi
    
    # Return to the k8s directory
    cd /Users/nolancrook/code/stable-diffusion-gitops
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
print_status "Checking cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Check your kubectl configuration."
    exit 1
fi

print_success "Connected to Kubernetes cluster"

# Deploy the application
print_status "Deploying Hauliday to $ENVIRONMENT environment..."

KUSTOMIZE_PATH="apps/hauliday/overlays/$ENVIRONMENT"

if [[ ! -d "$KUSTOMIZE_PATH" ]]; then
    print_error "Kustomize path not found: $KUSTOMIZE_PATH"
    exit 1
fi

# Apply the manifests
kubectl apply -k "$KUSTOMIZE_PATH"

if [[ $? -eq 0 ]]; then
    print_success "Hauliday manifests applied successfully"
else
    print_error "Failed to apply Hauliday manifests"
    exit 1
fi

# Verify deployment if requested
if [[ "$VERIFY_DEPLOYMENT" == true ]]; then
    print_status "Verifying deployment..."
    
    # Wait for deployment to be ready
    print_status "Waiting for deployment to be ready..."
    kubectl rollout status deployment/hauliday-frontend -n hauliday --timeout=300s
    
    if [[ $? -eq 0 ]]; then
        print_success "Deployment is ready"
    else
        print_error "Deployment failed to become ready within timeout"
        exit 1
    fi
    
    # Check pod status
    print_status "Checking pod status..."
    kubectl get pods -n hauliday -l app=hauliday-frontend
    
    # Check service status
    print_status "Checking service status..."
    kubectl get service -n hauliday hauliday-frontend
    
    # Check ingress status
    print_status "Checking ingress status..."
    kubectl get ingress -n hauliday hauliday-frontend
    
    # Test health endpoint
    print_status "Testing health endpoint..."
    kubectl run --rm -i --tty --restart=Never test-pod --image=curlimages/curl -- \
        curl -s http://hauliday-frontend.hauliday.svc.cluster.local/health
    
    print_success "Deployment verification completed"
fi

print_success "Hauliday deployment to $ENVIRONMENT completed successfully!"

# Show useful commands
echo ""
print_status "Useful commands for monitoring:"
echo "  kubectl get pods -n hauliday"
echo "  kubectl logs -n hauliday -l app=hauliday-frontend"
echo "  kubectl describe ingress hauliday-frontend -n hauliday"
echo "  kubectl port-forward -n hauliday svc/hauliday-frontend 8080:80"
echo ""
print_status "Website should be accessible at: http://haulidayrentals.com" 