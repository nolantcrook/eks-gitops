# Hauliday Equipment Rentals - Kubernetes Deployment

This directory contains the Kubernetes manifests for deploying the Hauliday Equipment Rentals website to your EKS cluster.

## Architecture

The deployment follows the Kustomize pattern with base configurations and environment-specific overlays:

```
hauliday/
├── base/                   # Base Kubernetes manifests
│   ├── namespace.yaml      # hauliday namespace
│   ├── deployment.yaml     # Frontend deployment
│   ├── service.yaml        # ClusterIP service
│   ├── ingress.yaml        # Ingress for haulidayrentals.com
│   └── kustomization.yaml  # Base kustomization
└── overlays/              # Environment-specific configurations
    ├── dev/               # Development environment
    └── prod/              # Production environment
```

## Configuration

### Base Configuration
- **Namespace**: `hauliday`
- **Image**: `891377073036.dkr.ecr.us-west-2.amazonaws.com/hauliday-frontend:latest`
- **Port**: 80 (HTTP)
- **Replicas**: 2 (dev), 3 (prod)

### Ingress Configuration
- **Host**: `haulidayrentals.com`
- **Path**: `/` (all paths)
- **Protocol**: HTTP (HTTPS terminated at ALB)
- **Ingress Class**: `nginx`

### Health Checks
- **Liveness Probe**: `/health` endpoint
- **Readiness Probe**: `/health` endpoint
- **Initial Delay**: 30s (liveness), 5s (readiness)

## Deployment

### Prerequisites
1. EKS cluster is running
2. kubectl is configured for your cluster
3. Hauliday frontend image is built and pushed to ECR

### Build and Push Image
```bash
cd /Users/nolancrook/code/api_docker/hauliday
./build-frontend.sh
```

### Deploy to Development
```bash
# From the stable-diffusion-gitops directory
kubectl apply -k apps/hauliday/overlays/dev
```

### Deploy to Production
```bash
# From the stable-diffusion-gitops directory
kubectl apply -k apps/hauliday/overlays/prod
```

### Verify Deployment
```bash
# Check namespace
kubectl get namespace hauliday

# Check deployment
kubectl get deployment -n hauliday

# Check pods
kubectl get pods -n hauliday

# Check service
kubectl get service -n hauliday

# Check ingress
kubectl get ingress -n hauliday

# Check logs
kubectl logs -n hauliday -l app=hauliday-frontend
```

## Environments

### Development Environment
- **Replicas**: 2
- **CPU Request**: 100m
- **Memory Request**: 128Mi
- **CPU Limit**: 200m
- **Memory Limit**: 256Mi

### Production Environment
- **Replicas**: 3
- **CPU Request**: 200m
- **Memory Request**: 256Mi
- **CPU Limit**: 500m
- **Memory Limit**: 512Mi

## Troubleshooting

### Common Issues

1. **Image Pull Errors**
   ```bash
   # Check ECR image exists
   aws ecr list-images --repository-name hauliday-frontend --region us-west-2
   
   # Update image tag if needed
   kubectl set image deployment/hauliday-frontend hauliday-frontend=891377073036.dkr.ecr.us-west-2.amazonaws.com/hauliday-frontend:latest -n hauliday
   ```

2. **Ingress Not Working**
   ```bash
   # Check ingress controller is running
   kubectl get pods -n ingress-nginx
   
   # Check ingress events
   kubectl describe ingress hauliday-frontend -n hauliday
   ```

3. **Health Check Failures**
   ```bash
   # Check if /health endpoint is accessible
   kubectl port-forward -n hauliday svc/hauliday-frontend 8080:80
   curl http://localhost:8080/health
   ```

### Update Deployment
```bash
# Update image tag
kubectl set image deployment/hauliday-frontend hauliday-frontend=891377073036.dkr.ecr.us-west-2.amazonaws.com/hauliday-frontend:new-tag -n hauliday

# Scale deployment
kubectl scale deployment/hauliday-frontend --replicas=5 -n hauliday

# Rolling restart
kubectl rollout restart deployment/hauliday-frontend -n hauliday
```

## Monitoring

### Check Application Status
```bash
# View deployment status
kubectl get deployment hauliday-frontend -n hauliday

# View pod status
kubectl get pods -n hauliday -l app=hauliday-frontend

# View service endpoints
kubectl get endpoints -n hauliday
```

### Access Logs
```bash
# View recent logs
kubectl logs -n hauliday -l app=hauliday-frontend --tail=100

# Follow logs
kubectl logs -n hauliday -l app=hauliday-frontend -f

# Logs from specific pod
kubectl logs -n hauliday <pod-name>
```

## DNS Configuration

Make sure your DNS for `haulidayrentals.com` points to your ALB/Load Balancer that routes traffic to your EKS cluster's nginx ingress controller.

## Security Notes

- HTTPS is terminated at the ALB level
- All traffic within the cluster is HTTP on port 80
- The application includes security headers via nginx configuration
- Health check endpoints are accessible without authentication 