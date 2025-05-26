#!/bin/bash

# Verify tco-demo deployment

echo "=== Tax Agent Demo Deployment Verification ==="
echo ""

# Check namespace
echo "1. Checking namespace..."
kubectl get namespace tco-demo

echo ""
echo "2. Checking pods..."
kubectl get pods -n tco-demo

echo ""
echo "3. Checking services..."
kubectl get svc -n tco-demo

echo ""
echo "4. Checking ingress..."
kubectl get ingress -n tco-demo

echo ""
echo "5. Checking secrets..."
kubectl get secrets -n tco-demo

echo ""
echo "6. Checking external secrets..."
kubectl get externalsecret -n tco-demo

echo ""
echo "7. Pod status details..."
kubectl describe pods -n tco-demo

echo ""
echo "8. Service account..."
kubectl get serviceaccount -n tco-demo

echo ""
echo "=== Verification Complete ==="
echo ""
echo "If all resources show as Ready/Running, the application should be accessible at:"
echo "https://tco-demo.nolancrook.com" 