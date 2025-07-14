# Umami Analytics Deployment Guide

This directory contains Kubernetes manifests for deploying Umami Analytics with PostgreSQL on EKS.

## Components

- **PostgreSQL Database**: Persistent storage with 20Gi EBS GP3 volume
- **Umami Application**: Web analytics application with 5Gi storage
- **EBS CSI Controller**: Service account and monitoring for volume provisioning
- **Ingress**: NGINX ingress for external access
- **Secrets**: External secrets integration with AWS Secrets Manager

## Quick Deploy

```bash
kubectl apply -k stable-diffusion-gitops/apps/umami/base/
```

## Troubleshooting

### EBS Volume Provisioning Issues

If PVCs are stuck in "Pending" state:

1. **Check EBS CSI Controller Status**:
   ```bash
   kubectl get deployment ebs-csi-controller -n kube-system
   kubectl get pods -n kube-system -l app=ebs-csi-controller
   ```

2. **Verify Service Account**:
   ```bash
   kubectl get serviceaccount ebs-csi-controller-sa -n kube-system
   kubectl describe serviceaccount ebs-csi-controller-sa -n kube-system
   ```

3. **Check IAM Role Annotation**:
   The service account should have:
   ```yaml
   annotations:
     eks.amazonaws.com/role-arn: arn:aws:iam::891377073036:role/eks-ebs-csi-driver-role-dev
   ```

4. **Restart EBS CSI Controller**:
   ```bash
   kubectl rollout restart deployment ebs-csi-controller -n kube-system
   ```

5. **Run Troubleshooting Script**:
   ```bash
   kubectl create job ebs-csi-troubleshoot-$(date +%s) --from=job/ebs-csi-troubleshoot -n kube-system
   kubectl logs -f job/ebs-csi-troubleshoot-$(date +%s) -n kube-system
   ```

### Common Issues and Solutions

#### Issue: PVCs Stuck in Pending
**Cause**: EBS CSI controller not running or missing IAM permissions
**Solution**: 
1. Verify EBS CSI controller pods are running
2. Check service account has proper IAM role annotation
3. Restart the controller deployment

#### Issue: Pods Stuck in ContainerCreating
**Cause**: Volume mounting failed
**Solution**:
1. Check if PVCs are bound
2. Verify storage class exists
3. Check AWS EBS volume limits

#### Issue: Database Connection Failed
**Cause**: PostgreSQL not ready or network issues
**Solution**:
1. Check postgres pod logs
2. Verify service endpoints
3. Check network policies

### Health Checks

#### Check Application Health
```bash
kubectl get pods -n umami
kubectl logs -f deployment/umami -n umami
kubectl logs -f deployment/postgres -n umami
```

#### Check Storage
```bash
kubectl get pvc -n umami
kubectl get pv
```

#### Check Services
```bash
kubectl get svc -n umami
kubectl get ingress -n umami
```

### Monitoring

The deployment includes:
- **Startup Probes**: Prevent premature restarts during initialization
- **Liveness Probes**: Restart unhealthy containers
- **Readiness Probes**: Control traffic routing
- **Pod Disruption Budgets**: Maintain availability during updates

### Spot Instance Configuration

The deployment includes tolerations for spot instances:
- Architecture-specific scheduling (amd64)
- Instance type tolerations
- Proper resource requests/limits

### Security

- **Service Accounts**: Dedicated SAs with minimal permissions
- **External Secrets**: Integration with AWS Secrets Manager
- **Network Policies**: Restricted network access
- **Pod Security**: Security contexts and policies

## Scaling

### Horizontal Scaling
```bash
kubectl scale deployment umami --replicas=3 -n umami
```

### Vertical Scaling
Update resource limits in the deployment manifest and reapply.

### Storage Scaling
```bash
kubectl patch pvc postgres-pvc -n umami -p '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}'
```

## Backup and Recovery

### Database Backup
```bash
kubectl exec -it deployment/postgres -n umami -- pg_dump -U umami umami > umami-backup.sql
```

### Restore Database
```bash
kubectl exec -i deployment/postgres -n umami -- psql -U umami -d umami < umami-backup.sql
```

## Performance Tuning

### PostgreSQL Optimization
- Adjust `shared_buffers` and `work_mem` based on node resources
- Configure connection pooling for high-traffic scenarios
- Monitor query performance with `pg_stat_statements`

### Umami Optimization
- Increase replica count for high availability
- Configure proper resource limits
- Enable gzip compression in nginx ingress

## Maintenance

### Regular Tasks
1. Monitor disk usage and scale storage as needed
2. Update container images regularly
3. Rotate secrets and certificates
4. Review and update resource limits

### Upgrade Process
1. Backup database
2. Update image tags in manifests
3. Apply rolling updates
4. Verify application functionality
5. Monitor for issues

## Support

For issues:
1. Check application logs
2. Review Kubernetes events
3. Run troubleshooting scripts
4. Check AWS CloudWatch for EBS metrics
5. Review ArgoCD application status 