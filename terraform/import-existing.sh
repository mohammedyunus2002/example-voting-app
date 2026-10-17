#!/usr/bin/env bash
# Adopt resources left behind by an apply that did not keep its state file.
set -u

import_id() {
  local addr="$1"
  local id="$2"
  if [[ -z "${id}" || "${id}" == "None" || "${id}" == "null" || "${id}" == *"None"* || "${id}" == *"null"* ]]; then
    echo "skip ${addr}: not found in AWS"
    return 0
  fi
  if terraform state show "${addr}" >/dev/null 2>&1; then
    echo "skip ${addr}: already in state"
    return 0
  fi
  echo "import ${addr} ${id}"
  terraform import "${addr}" "${id}" || echo "skip ${addr}: import failed"
}

account="$(aws sts get-caller-identity --query Account --output text)"
policy_arn() {
  echo "arn:aws:iam::${account}:policy/$1"
}
subnet_by_name() {
  aws ec2 describe-subnets \
    --filters "Name=tag:Name,Values=$1" "Name=vpc-id,Values=${vpc_id}" \
    --query 'Subnets[0].SubnetId' --output text
}

# The subnets already exist. Use their VPC, not whichever VPC happens to be named staging-main.
vpc_id="$(aws ec2 describe-subnets --filters Name=tag:Name,Values=staging-private-us-east-2a --query 'Subnets[0].VpcId' --output text)"
if [[ -z "${vpc_id}" || "${vpc_id}" == "None" ]]; then
  vpc_id="$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=staging-main --query 'Vpcs[0].VpcId' --output text)"
fi

state_vpc="$(terraform state show aws_vpc.main 2>/dev/null | sed -n 's/^ *id *= *"\(vpc-[^"]*\)".*/\1/p' | head -1)"
if [[ -n "${state_vpc}" && "${state_vpc}" != "${vpc_id}" ]]; then
  echo "state has ${state_vpc}; existing subnets are in ${vpc_id}. Rebinding network resources."
  for addr in \
    aws_route_table_association.private_zone1 \
    aws_route_table_association.private_zone2 \
    aws_route_table_association.public_zone1 \
    aws_route_table_association.public_zone2 \
    aws_route_table.private \
    aws_route_table.public \
    aws_nat_gateway.nat \
    aws_eip.nat \
    aws_internet_gateway.igw \
    aws_subnet.private_zone1 \
    aws_subnet.private_zone2 \
    aws_subnet.public_zone1 \
    aws_subnet.public_zone2 \
    aws_vpc.main
  do
    terraform state rm "${addr}" >/dev/null 2>&1 || true
  done
fi

import_id aws_vpc.main "${vpc_id}"
import_id aws_subnet.private_zone1 "$(subnet_by_name staging-private-us-east-2a)"
import_id aws_subnet.private_zone2 "$(subnet_by_name staging-private-us-east-2b)"
import_id aws_subnet.public_zone1 "$(subnet_by_name staging-public-us-east-2a)"
import_id aws_subnet.public_zone2 "$(subnet_by_name staging-public-us-east-2b)"
import_id aws_internet_gateway.igw "$(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values="${vpc_id}" --query 'InternetGateways[0].InternetGatewayId' --output text)"
nat_id="$(aws ec2 describe-nat-gateways --filter Name=vpc-id,Values="${vpc_id}" Name=state,Values=available,pending --query 'NatGateways[0].NatGatewayId' --output text)"
import_id aws_nat_gateway.nat "${nat_id}"
import_id aws_eip.nat "$(aws ec2 describe-nat-gateways --filter Name=vpc-id,Values="${vpc_id}" Name=state,Values=available,pending --query 'NatGateways[0].NatGatewayAddresses[0].AllocationId' --output text)"
import_id aws_route_table.private "$(aws ec2 describe-route-tables --filters Name=vpc-id,Values="${vpc_id}" Name=tag:Name,Values=staging-private --query 'RouteTables[0].RouteTableId' --output text)"
import_id aws_route_table.public "$(aws ec2 describe-route-tables --filters Name=vpc-id,Values="${vpc_id}" Name=tag:Name,Values=staging-public --query 'RouteTables[0].RouteTableId' --output text)"

import_association() {
  local addr="$1"
  local subnet="$2"
  local rtb
  rtb="$(aws ec2 describe-route-tables --filters Name=association.subnet-id,Values="${subnet}" --query 'RouteTables[0].RouteTableId' --output text)"
  if [[ -z "${rtb}" || "${rtb}" == "None" ]]; then
    rtb="$(aws ec2 describe-route-tables --filters Name=vpc-id,Values="${vpc_id}" Name=association.main,Values=true --query 'RouteTables[0].RouteTableId' --output text)"
  fi
  import_id "${addr}" "${subnet}/${rtb}"
}

import_association aws_route_table_association.private_zone1 "$(subnet_by_name staging-private-us-east-2a)"
import_association aws_route_table_association.private_zone2 "$(subnet_by_name staging-private-us-east-2b)"
import_association aws_route_table_association.public_zone1 "$(subnet_by_name staging-public-us-east-2a)"
import_association aws_route_table_association.public_zone2 "$(subnet_by_name staging-public-us-east-2b)"

import_id aws_iam_role.eks staging-demo-eks-cluster
import_id aws_iam_role.nodes staging-demo-eks-nodes
import_id aws_iam_role.eks_admin staging-demo-eks-admin
import_id aws_iam_role.aws_lbc staging-demo-aws-lbc
import_id aws_iam_role.cluster_autoscaler staging-demo-cluster-autoscaler
import_id aws_iam_role.ebs_csi_driver staging-demo-ebs-csi-driver
import_id aws_iam_role.efs_csi_driver staging-demo-efs-csi-driver
import_id aws_iam_role.myapp_secrets staging-demo-myapp-secrets
import_id aws_iam_user.developer developer
import_id aws_iam_user.manager manager

import_id aws_iam_policy.eks_admin "$(policy_arn AmazonEKSAdminPolicy)"
import_id aws_iam_policy.eks_assume_admin "$(policy_arn AmazonEKSAssumeAdminPolicy)"
import_id aws_iam_policy.developer_eks "$(policy_arn AmazonEKSDeveloperPolicy)"
import_id aws_iam_policy.aws_lbc "$(policy_arn AWSLoadBalancerController)"
import_id aws_iam_policy.cluster_autoscaler "$(policy_arn staging-demo-cluster-autoscaler)"
import_id aws_iam_policy.ebs_csi_driver_encryption "$(policy_arn staging-demo-ebs-csi-driver-encryption)"
import_id aws_iam_policy.myapp_secrets "$(policy_arn staging-demo-myapp-secrets)"

import_id aws_iam_role_policy_attachment.eks "staging-demo-eks-cluster/arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
import_id aws_iam_role_policy_attachment.amazon_eks_worker_node_policy "staging-demo-eks-nodes/arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
import_id aws_iam_role_policy_attachment.amazon_eks_cni_policy "staging-demo-eks-nodes/arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
import_id aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only "staging-demo-eks-nodes/arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
import_id aws_iam_role_policy_attachment.eks_admin "staging-demo-eks-admin/$(policy_arn AmazonEKSAdminPolicy)"
import_id aws_iam_user_policy_attachment.manager "manager/$(policy_arn AmazonEKSAssumeAdminPolicy)"
import_id aws_iam_user_policy_attachment.developer_eks "developer/$(policy_arn AmazonEKSDeveloperPolicy)"
import_id aws_iam_role_policy_attachment.aws_lbc "staging-demo-aws-lbc/$(policy_arn AWSLoadBalancerController)"
import_id aws_iam_role_policy_attachment.cluster_autoscaler "staging-demo-cluster-autoscaler/$(policy_arn staging-demo-cluster-autoscaler)"
import_id aws_iam_role_policy_attachment.ebs_csi_driver "staging-demo-ebs-csi-driver/arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
import_id aws_iam_role_policy_attachment.ebs_csi_driver_encryption "staging-demo-ebs-csi-driver/$(policy_arn staging-demo-ebs-csi-driver-encryption)"
import_id aws_iam_role_policy_attachment.efs_csi_driver "staging-demo-efs-csi-driver/arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
import_id aws_iam_role_policy_attachment.myapp_secrets "staging-demo-myapp-secrets/$(policy_arn staging-demo-myapp-secrets)"

import_id aws_efs_file_system.eks "$(aws efs describe-file-systems --creation-token eks --query 'FileSystems[0].FileSystemId' --output text)"

if aws eks describe-cluster --name staging-demo >/dev/null 2>&1; then
  import_id aws_eks_cluster.eks staging-demo
fi
