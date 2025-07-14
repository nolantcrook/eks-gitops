# Umami Analytics Deployment Guide

This directory contains Kubernetes manifests for deploying Umami Analytics with PostgreSQL on EKS using EFS storage.

## Components

- **PostgreSQL Database**: Persistent storage with 20Gi EFS volume
- **Umami Application**: Web analytics application with 5Gi EFS storage
- **EFS Storage**: ReadWriteMany volumes for scalable storage
- **Ingress**: NGINX ingress for external access
- **Secrets**: External secrets integration with AWS Secrets Manager

## Quick Deploy

```bash
kubectl apply -k stable-diffusion-gitops/apps/umami/overlays/dev/
```

## Storage Architecture

### EFS Benefits
- **ReadWriteMany**: Multiple pods can mount the same volume simultaneously
- **No Multi-Attach Errors**: Unlike EBS, EFS supports concurrent access
- **Automatic Scaling**: EFS scales automatically with usage
- **Cross-AZ Access**: Volumes can be accessed from any availability zone

### Volume Configuration
```yaml
persistentVolumeClaim:
  name: postgres-pvc
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  storage: 20Gi
```

## Troubleshooting

### Storage Issues

If pods are stuck in "ContainerCreating" state:

1. **Check EFS CSI Driver Status**:
   ```bash
   kubectl get pods -n kube-system | grep efs-csi
   ```

2. **Verify EFS Mount Status**:
   ```bash
   kubectl get pvc -n umami
   kubectl get pv
   ```

3. **Check Storage Class**:
   ```bash
   kubectl get storageclass efs-sc
   ```

4. **Run Storage Troubleshooting**:
   ```bash
   kubectl create configmap storage-troubleshoot -n umami --from-file=troubleshoot.sh
   kubectl create job storage-check --image=bitnami/kubectl:latest -n umami
   ```

### Common Issues and Solutions

#### Issue: PVCs Stuck in Pending
**Cause**: EFS CSI driver not running or EFS filesystem not available
**Solution**: 
1. Verify EFS CSI driver pods are running
2. Check EFS filesystem exists and is accessible
3. Verify EFS access points configuration

#### Issue: Pods Can't Mount EFS
**Cause**: Security groups or NFS access issues
**Solution**:
1. Check security groups allow NFS (port 2049)
2. Verify EFS mount targets in correct subnets
3. Check EFS access point permissions

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
kubectl describe pvc postgres-pvc -n umami
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

### EFS-Specific Configuration

- **No Architecture Constraints**: EFS works on any node architecture
- **Shared Storage**: Multiple replicas can share the same data
- **Sub-Path Mounting**: Uses subPaths to isolate data (postgres, umami)
- **Automatic Provisioning**: EFS access points handle provisioning

### Security

- **Service Accounts**: Dedicated SAs with minimal permissions
- **External Secrets**: Integration with AWS Secrets Manager
- **Network Policies**: Restricted network access
- **EFS Encryption**: Volumes encrypted at rest and in transit

## Scaling

### Horizontal Scaling
```bash
kubectl scale deployment umami --replicas=3 -n umami
```

### Vertical Scaling
Update resource limits in the deployment manifest and reapply.

### Storage Scaling
EFS scales automatically - no manual intervention needed.

## Backup and Recovery

### Database Backup
```bash
kubectl exec -it deployment/postgres -n umami -- pg_dump -U umami umami > umami-backup.sql
```

### Restore Database
```bash
kubectl exec -i deployment/postgres -n umami -- psql -U umami -d umami < umami-backup.sql
```

### EFS Backup
- AWS Backup automatically handles EFS backups
- Point-in-time recovery available through AWS console
- Cross-region replication supported

## Performance Tuning

### PostgreSQL Optimization
- Adjust `shared_buffers` and `work_mem` based on node resources
- Configure connection pooling for high-traffic scenarios
- Monitor query performance with `pg_stat_statements`

### Umami Optimization
- Increase replica count for high availability
- Configure proper resource limits
- Enable gzip compression in nginx ingress

### EFS Performance
- Use General Purpose performance mode for most workloads
- Consider Provisioned Throughput for high-performance needs
- Monitor EFS metrics in CloudWatch

## Maintenance

### Regular Tasks
1. Monitor EFS usage and performance metrics
2. Update container images regularly
3. Rotate secrets and certificates
4. Review and update resource limits

### Upgrade Process
1. Backup database
2. Update image tags in manifests
3. Apply rolling updates (no downtime with EFS)
4. Verify application functionality
5. Monitor for issues

## Migration from EBS to EFS

### What Changed
- **Storage Class**: `gp3` → `efs-sc`
- **Access Mode**: `ReadWriteOnce` → `ReadWriteMany`
- **Volume Type**: EBS GP3 → EFS
- **Architecture**: Removed node selectors and tolerations
- **Monitoring**: Updated to focus on EFS instead of EBS CSI

### Benefits Gained
- ✅ No more multi-attach errors
- ✅ Multiple replicas can share storage
- ✅ Cross-AZ accessibility
- ✅ Automatic scaling
- ✅ Better for stateful applications

## Support

For issues:
1. Check application logs
2. Review Kubernetes events
3. Check EFS mount status
4. Review AWS CloudWatch for EFS metrics
5. Verify security groups and NFS access 