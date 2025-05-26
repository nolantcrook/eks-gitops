# Tax Agent Demo - Kubernetes Deployment

This directory contains the Kubernetes manifests for deploying the Transformco Write-Off Processing application (tco-demo) to a Kubernetes cluster.

## Application Overview

The tco-demo is an agent-based application that:
- Processes inventory CSV files
- Calculates write-off losses using AI agents
- Downloads and fills IRS Form 1125-A
- Provides a React-based frontend for workflow visualization

## Architecture

The application consists of:
- **Backend**: FastAPI application with LangChain agents (Port 8001)
- **Frontend**: Next.js React application (Port 3000)
- **Ingress**: Routes traffic to both frontend and backend
- **Secrets**: OpenAI API key from AWS Secrets Manager

## Prerequisites

1. AWS CLI configured with appropriate permissions
2. Docker installed
3. kubectl configured for your Kubernetes cluster
4. AWS Secrets Manager secret created at `tco-demo/openai-api-key`
5. IAM role `tco-demo-role` with Secrets Manager access

## Deployment Steps

### 1. Build and Push Docker Images

From the demo-transformco directory:

```bash
cd /Users/nolancrook/code/api_docker/demo-transformco
./build-all.sh
```

This will:
- Build both backend and frontend Docker images
- Create ECR repositories if they don't exist
- Push images to ECR

### 2. Deploy to Kubernetes

```bash
kubectl apply -k /Users/nolancrook/code/stable-diffusion-gitops/apps/tco-demo/base
```

### 3. Verify Deployment

```bash
# Check pods
kubectl get pods -n tco-demo

# Check services
kubectl get svc -n tco-demo

# Check ingress
kubectl get ingress -n tco-demo

# Check secrets
kubectl get secrets -n tco-demo
```

## Access

Once deployed, the application will be available at:
- **Frontend**: https://tco-demo.nolancrook.com
- **Backend API**: https://tco-demo.nolancrook.com/api

## Configuration

### Environment Variables

**Backend:**
- `OPENAI_API_KEY`: Retrieved from AWS Secrets Manager

**Frontend:**
- `NEXT_PUBLIC_API_URL`: Set to `https://tco-demo.nolancrook.com/api`

### Volumes

The deployment uses emptyDir volumes for:
- `/app/uploads`: Temporary file uploads
- `/app/results`: Generated PDF files
- `/app/blank_forms`: Form templates

### Resources

**Backend:**
- Requests: 500m CPU, 512Mi memory
- Limits: 1000m CPU, 1Gi memory

**Frontend:**
- Requests: 250m CPU, 256Mi memory
- Limits: 500m CPU, 512Mi memory

## Secrets Management

The application uses External Secrets Operator to retrieve the OpenAI API key from AWS Secrets Manager:

- **Secret Path**: `tco-demo/openai-api-key`
- **Property**: `key`
- **Service Account**: `tco-demo-sa`
- **IAM Role**: `arn:aws:iam::891377073036:role/tco-demo-role`

## Troubleshooting

### Check Pod Logs

```bash
# Backend logs
kubectl logs -n tco-demo deployment/tco-demo -c backend

# Frontend logs
kubectl logs -n tco-demo deployment/tco-demo -c frontend
```

### Check Secret Status

```bash
kubectl describe externalsecret -n tco-demo tco-demo-external-secrets
```

### Common Issues

1. **Images not found**: Ensure Docker images are built and pushed to ECR
2. **Secret access denied**: Verify IAM role and Secrets Manager permissions
3. **Ingress not working**: Check nginx-ingress controller and DNS configuration

## Updating the Application

To update the application:

1. Make changes to the source code
2. Rebuild and push images: `./build-all.sh`
3. Restart the deployment: `kubectl rollout restart deployment/tco-demo -n tco-demo` 