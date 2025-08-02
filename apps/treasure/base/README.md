# treasure Application Deployment

This directory contains Kubernetes manifests for deploying the treasure baby monitor website to EKS.

## Architecture

- **Frontend**: React application serving the treasure website (port 3000)
- **Backend**: FastAPI application handling preorders via AWS SES (port 8000)
- **Namespace**: `treasure`
- **Domain**: `aitreasuremap.com`

## Components

### Frontend (`treasure-frontend`)
- **Image**: `891377073036.dkr.ecr.us-west-2.amazonaws.com/treasure-frontend:latest`
- **Port**: 3000 (internal), 80 (service)
- **Environment**: 
  - `REACT_APP_API_URL`: `http://treasure-backend:8000`
- **Health Check**: HTTP GET `/` on port 3000

### Backend (`treasure-backend`)
- **Image**: `891377073036.dkr.ecr.us-west-2.amazonaws.com/treasure-backend:latest`
- **Port**: 8000
- **Environment**:
  - `AWS_REGION`: `us-west-2`
  - `SES_FROM_EMAIL`: `nolan@aitreasuremap.com`
  - `ENVIRONMENT`: `production`
- **Health Check**: HTTP GET `/health` on port 8000
- **AWS Permissions**: SES send email via IAM role `eks-treasure-role`

## Services

- **treasure-frontend**: ClusterIP service exposing frontend on port 80
- **treasure-backend**: ClusterIP service exposing backend on port 8000

## Ingress

- **Host**: `aitreasuremap.com`
- **Controller**: AWS ALB Ingress Controller
- **SSL**: Automatic redirect HTTP → HTTPS
- **Backend**: Routes to `treasure-frontend` service

## Prerequisites

1. **EKS Cluster** with AWS ALB Ingress Controller installed
2. **ECR Images** built and pushed:
   ```bash
   # Build and push frontend
   docker build -t 891377073036.dkr.ecr.us-west-2.amazonaws.com/treasure-frontend:latest ./frontend
   docker push 891377073036.dkr.ecr.us-west-2.amazonaws.com/treasure-frontend:latest
   
   # Build and push backend  
   docker build -t 891377073036.dkr.ecr.us-west-2.amazonaws.com/treasure-backend:latest ./backend
   docker push 891377073036.dkr.ecr.us-west-2.amazonaws.com/treasure-backend:latest
   ```
3. **AWS SES** configured with verified domain/email
4. **IAM Role** `eks-treasure-role` with SES permissions
5. **DNS** pointing `aitreasuremap.com` to ALB

## Deployment

```bash
# Deploy all resources
kubectl apply -k .

# Check deployment status
kubectl get pods -n treasure
kubectl get services -n treasure
kubectl get ingress -n treasure

# View logs
kubectl logs -f deployment/treasure-frontend -n treasure
kubectl logs -f deployment/treasure-backend -n treasure
```

## Communication Flow

1. **External**: `https://aitreasuremap.com` → ALB → `treasure-frontend:80`
2. **Internal**: Frontend → `http://treasure-backend:8000/api/preorder`
3. **AWS SES**: Backend → SES → `nolan@aitreasuremap.com`

## Required IAM Permissions for `eks-treasure-role`

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

- **Frontend Health**: `http://treasure-frontend/`
- **Backend Health**: `http://treasure-backend:8000/health`
- **API Documentation**: `http://treasure-backend:8000/docs` (if enabled)

## Troubleshooting

### Frontend Issues
```bash
# Check if frontend can reach backend
kubectl exec -it deployment/treasure-frontend -n treasure -- curl http://treasure-backend:8000/health
```

### Backend Issues
```bash
# Check AWS credentials
kubectl logs deployment/treasure-backend -n treasure | grep -i aws

# Test SES permissions
kubectl exec -it deployment/treasure-backend -n treasure -- python -c "import boto3; print(boto3.client('ses').list_verified_email_addresses())"
```

### CORS Issues
Check that backend allows `aitreasuremap.com` origin in CORS configuration.

## Scaling

```bash
# Scale frontend
kubectl scale deployment treasure-frontend --replicas=3 -n treasure

# Scale backend  
kubectl scale deployment treasure-backend --replicas=3 -n treasure
``` 