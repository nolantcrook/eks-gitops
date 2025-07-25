# Tolby Application Deployment

This directory contains Kubernetes manifests for deploying the Tolby baby monitor website to EKS.

## Architecture

- **Frontend**: React application serving the Tolby website (port 3000)
- **Backend**: FastAPI application handling preorders via AWS SES (port 8000)
- **Namespace**: `tolby`
- **Domain**: `tolby.co`

## Components

### Frontend (`tolby-frontend`)
- **Image**: `891377073036.dkr.ecr.us-west-2.amazonaws.com/tolby-frontend:latest`
- **Port**: 3000 (internal), 80 (service)
- **Environment**: 
  - `REACT_APP_API_URL`: `http://tolby-backend:8000`
- **Health Check**: HTTP GET `/` on port 3000

### Backend (`tolby-backend`)
- **Image**: `891377073036.dkr.ecr.us-west-2.amazonaws.com/tolby-backend:latest`
- **Port**: 8000
- **Environment**:
  - `AWS_REGION`: `us-west-2`
  - `SES_FROM_EMAIL`: `nolan@tolby.co`
  - `ENVIRONMENT`: `production`
- **Health Check**: HTTP GET `/health` on port 8000
- **AWS Permissions**: SES send email via IAM role `eks-tolby-role`

## Services

- **tolby-frontend**: ClusterIP service exposing frontend on port 80
- **tolby-backend**: ClusterIP service exposing backend on port 8000

## Ingress

- **Host**: `tolby.co`
- **Controller**: AWS ALB Ingress Controller
- **SSL**: Automatic redirect HTTP → HTTPS
- **Backend**: Routes to `tolby-frontend` service

## Prerequisites

1. **EKS Cluster** with AWS ALB Ingress Controller installed
2. **ECR Images** built and pushed:
   ```bash
   # Build and push frontend
   docker build -t 891377073036.dkr.ecr.us-west-2.amazonaws.com/tolby-frontend:latest ./frontend
   docker push 891377073036.dkr.ecr.us-west-2.amazonaws.com/tolby-frontend:latest
   
   # Build and push backend  
   docker build -t 891377073036.dkr.ecr.us-west-2.amazonaws.com/tolby-backend:latest ./backend
   docker push 891377073036.dkr.ecr.us-west-2.amazonaws.com/tolby-backend:latest
   ```
3. **AWS SES** configured with verified domain/email
4. **IAM Role** `eks-tolby-role` with SES permissions
5. **DNS** pointing `tolby.co` to ALB

## Deployment

```bash
# Deploy all resources
kubectl apply -k .

# Check deployment status
kubectl get pods -n tolby
kubectl get services -n tolby
kubectl get ingress -n tolby

# View logs
kubectl logs -f deployment/tolby-frontend -n tolby
kubectl logs -f deployment/tolby-backend -n tolby
```

## Communication Flow

1. **External**: `https://tolby.co` → ALB → `tolby-frontend:80`
2. **Internal**: Frontend → `http://tolby-backend:8000/api/preorder`
3. **AWS SES**: Backend → SES → `nolan@tolby.co`

## Required IAM Permissions for `eks-tolby-role`

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ses:SendEmail",
                "ses:SendRawEmail"
            ],
            "Resource": "*"
        }
    ]
}
```

## Monitoring

- **Frontend Health**: `http://tolby-frontend/`
- **Backend Health**: `http://tolby-backend:8000/health`
- **API Documentation**: `http://tolby-backend:8000/docs` (if enabled)

## Troubleshooting

### Frontend Issues
```bash
# Check if frontend can reach backend
kubectl exec -it deployment/tolby-frontend -n tolby -- curl http://tolby-backend:8000/health
```

### Backend Issues
```bash
# Check AWS credentials
kubectl logs deployment/tolby-backend -n tolby | grep -i aws

# Test SES permissions
kubectl exec -it deployment/tolby-backend -n tolby -- python -c "import boto3; print(boto3.client('ses').list_verified_email_addresses())"
```

### CORS Issues
Check that backend allows `tolby.co` origin in CORS configuration.

## Scaling

```bash
# Scale frontend
kubectl scale deployment tolby-frontend --replicas=3 -n tolby

# Scale backend  
kubectl scale deployment tolby-backend --replicas=3 -n tolby
``` 