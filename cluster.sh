#!/bin/bash
# cluster.sh — elasticsearch-k8s-lab helper
# Usage: ./cluster.sh [start|stop|status|connect-cp|connect-worker|destroy]

cd "$(dirname "$0")/terraform"

CONTROL=$(terraform output -raw control_plane_instance_id 2>/dev/null)
WORKER=$(terraform output -raw worker_instance_id 2>/dev/null)

case "$1" in
  start)
    echo "Starting ES K8s lab cluster..."
    aws ec2 start-instances --instance-ids $CONTROL $WORKER --output text
    echo "Waiting 90 seconds for instances and SSM..."
    sleep 90
    echo ""
    echo "Instance status:"
    aws ec2 describe-instances \
      --instance-ids $CONTROL $WORKER \
      --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value|[0],State.Name,PrivateIpAddress]" \
      --output table
    echo ""
    echo "SSM status:"
    aws ssm describe-instance-information \
      --query "InstanceInformationList[].[InstanceId,PingStatus,ComputerName]" \
      --output table
    echo ""
    echo "Connect to control plane:"
    echo "  aws ssm start-session --target $CONTROL"
    ;;
  stop)
    echo "Stopping ES K8s lab cluster..."
    aws ec2 stop-instances --instance-ids $CONTROL $WORKER --output text
    sleep 5
    aws ec2 describe-instances \
      --instance-ids $CONTROL $WORKER \
      --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value|[0],State.Name]" \
      --output table
    echo "Cluster stopped. Cost: ~\$0.003/hr (EBS storage only)"
    ;;
  status)
    echo "Instance status:"
    aws ec2 describe-instances \
      --instance-ids $CONTROL $WORKER \
      --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value|[0],InstanceId,State.Name,PrivateIpAddress]" \
      --output table
    echo ""
    echo "SSM status:"
    aws ssm describe-instance-information \
      --query "InstanceInformationList[].[InstanceId,PingStatus,ComputerName]" \
      --output table
    ;;
  connect-cp)
    echo "Connecting to control plane..."
    aws ssm start-session --target $CONTROL
    ;;
  connect-worker)
    echo "Connecting to worker node..."
    aws ssm start-session --target $WORKER
    ;;
  destroy)
    echo "WARNING: Permanently deletes everything."
    echo "Press Ctrl-C to cancel, Enter to proceed..."
    read
    terraform destroy -auto-approve
    ;;
  *)
    echo "ES K8s Lab Helper"
    echo "Usage: ./cluster.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start          Start both EC2 instances"
    echo "  stop           Stop both EC2 instances"
    echo "  status         Show instance and SSM status"
    echo "  connect-cp     SSM into control plane"
    echo "  connect-worker SSM into worker node"
    echo "  destroy        Permanently delete everything"
    ;;
esac
