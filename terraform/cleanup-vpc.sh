#!/usr/bin/env bash
# Remove resources EKS leaves behind so DeleteVpc can succeed.
set -u

region="${AWS_REGION:-us-east-2}"

if aws eks describe-cluster --name staging-demo --region "${region}" >/dev/null 2>&1; then
  aws eks delete-nodegroup --cluster-name staging-demo --nodegroup-name general --region "${region}" >/dev/null 2>&1 || true
  aws eks wait nodegroup-deleted --cluster-name staging-demo --nodegroup-name general --region "${region}" >/dev/null 2>&1 || true
  aws eks delete-cluster --name staging-demo --region "${region}" >/dev/null 2>&1 || true
  aws eks wait cluster-deleted --name staging-demo --region "${region}" >/dev/null 2>&1 || true
fi

vpcs="$(aws ec2 describe-vpcs --region "${region}" --filters Name=tag:Name,Values=staging-main --query 'Vpcs[].VpcId' --output text)"
for vpc in ${vpcs}; do
  echo "Removing dependencies in ${vpc}"

  for arn in $(aws elbv2 describe-load-balancers --region "${region}" --query "LoadBalancers[?VpcId=='${vpc}'].LoadBalancerArn" --output text); do
    aws elbv2 delete-load-balancer --region "${region}" --load-balancer-arn "${arn}" || true
  done

  for nat in $(aws ec2 describe-nat-gateways --region "${region}" --filter Name=vpc-id,Values="${vpc}" Name=state,Values=pending,available --query 'NatGateways[].NatGatewayId' --output text); do
    aws ec2 delete-nat-gateway --region "${region}" --nat-gateway-id "${nat}" || true
  done
  aws ec2 wait nat-gateway-deleted --region "${region}" --filter Name=vpc-id,Values="${vpc}" >/dev/null 2>&1 || true

  for igw in $(aws ec2 describe-internet-gateways --region "${region}" --filters Name=attachment.vpc-id,Values="${vpc}" --query 'InternetGateways[].InternetGatewayId' --output text); do
    aws ec2 detach-internet-gateway --region "${region}" --internet-gateway-id "${igw}" --vpc-id "${vpc}" || true
    aws ec2 delete-internet-gateway --region "${region}" --internet-gateway-id "${igw}" || true
  done

  for eni in $(aws ec2 describe-network-interfaces --region "${region}" --filters Name=vpc-id,Values="${vpc}" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text); do
    aws ec2 delete-network-interface --region "${region}" --network-interface-id "${eni}" || true
  done

  for subnet in $(aws ec2 describe-subnets --region "${region}" --filters Name=vpc-id,Values="${vpc}" --query 'Subnets[].SubnetId' --output text); do
    aws ec2 delete-subnet --region "${region}" --subnet-id "${subnet}" || true
  done

  for rtb in $(aws ec2 describe-route-tables --region "${region}" --filters Name=vpc-id,Values="${vpc}" --query 'RouteTables[?Associations[?Main!=`true`]].RouteTableId' --output text); do
    aws ec2 delete-route-table --region "${region}" --route-table-id "${rtb}" || true
  done

  for sg in $(aws ec2 describe-security-groups --region "${region}" --filters Name=vpc-id,Values="${vpc}" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text); do
    aws ec2 delete-security-group --region "${region}" --group-id "${sg}" || true
  done

  aws ec2 delete-vpc --region "${region}" --vpc-id "${vpc}" || echo "VPC ${vpc} still has a dependency; destroy can be retried."
done
