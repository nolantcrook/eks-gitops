# Stable Diffusion GitOps Repository

This repository contains the GitOps configuration for deploying Stable Diffusion to Kubernetes using ArgoCD.

## Structure
- `argocd/`: ArgoCD installation and configuration
  - `install/`: ArgoCD installation manifests
  - `applications/`: Application definitions
  - `projects/`: Project definitions
- `apps/`: Application manifests
  - `stable-diffusion/`: Stable Diffusion application
    - `base/`: Base Kubernetes manifests
    - `overlays/`: Environment-specific configurations
      - `dev/`: Development environment
      - `prod/`: Production environment

## Installation Steps

### 1. Install ArgoCD
```bash
# Create ArgoCD namespace
kubectl apply -f argocd/install/namespace.yaml

# Install ArgoCD
kubectl apply -f argocd/install/service.yaml
```

### 2. Configure ArgoCD
```bash
# Create project
kubectl apply -f argocd/projects/stable-diffusion.yaml

# Create application
kubectl apply -f argocd/applications/stable-diffusion.yaml
```

### 3. Access ArgoCD UI
```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward the ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then access the UI at: https://localhost:8080

## Environments

### Development
- Single replica
- Lower resource limits
- Used for testing and development

### Production
- Multiple replicas for high availability
- Higher resource limits
- Used for production workloads

## Configuration
- Base configuration in `apps/stable-diffusion/base/`
- Environment-specific configurations in `apps/stable-diffusion/overlays/`
- ArgoCD configurations in `argocd/`

## Notes
- Update the repository URL in `argocd/applications/stable-diffusion.yaml`
- Adjust resource requests/limits in overlay configurations as needed
- Review and update container image registry URLs before deployment