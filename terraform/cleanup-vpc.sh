#!/usr/bin/env bash
# Remove resources EKS leaves behind so DeleteVpc can succeed.
set -u

region="${AWS_REGION:-us-east-2}"

if aws eks describe-cluster --name staging-demo --region "${region}" >/dev/null 2>&1; then
  echo "Deleting EKS cluster staging-demo"
  aws eks delete-nodegroup --cluster-name staging-demo --nodegroup-name general --region "${region}" >/dev/null 2>&1 || true
  aws eks wait nodegroup-deleted --cluster-name staging-demo --nodegroup-name general --region "${region}" >/dev/null 2>&1 || true
  aws eks delete-cluster --name staging-demo --region "${region}" >/dev/null 2>&1 || true
  aws eks wait cluster-deleted --name staging-demo --region "${region}" >/dev/null 2>&1 || true
fi

sweep_vpc() {
  local vpc="$1"
  echo "Removing dependencies in ${vpc}"

  local endpoints
  endpoints="$(aws ec2 describe-vpc-endpoints --region "${region}" --filters Name=vpc-id,Values="${vpc}" --query 'VpcEndpoints[].VpcEndpointId' --output text)"
  if [[ -n "${endpoints}" && "${endpoints}" != "None" ]]; then
    echo "VPC endpoints: ${endpoints}"
    aws ec2 delete-vpc-endpoints --region "${region}" --vpc-endpoint-ids ${endpoints} || true
  fi

  for arn in $(aws elbv2 describe-load-balancers --region "${region}" --query "LoadBalancers[?VpcId=='${vpc}'].LoadBalancerArn" --output text); do
    echo "Deleting load balancer ${arn}"
    aws elbv2 delete-load-balancer --region "${region}" --load-balancer-arn "${arn}" || true
  done

  for nat in $(aws ec2 describe-nat-gateways --region "${region}" --filter Name=vpc-id,Values="${vpc}" Name=state,Values=pending,available,deleting --query 'NatGateways[].NatGatewayId' --output text); do
    echo "Deleting NAT gateway ${nat}"
    aws ec2 delete-nat-gateway --region "${region}" --nat-gateway-id "${nat}" || true
  done

  for igw in $(aws ec2 describe-internet-gateways --region "${region}" --filters Name=attachment.vpc-id,Values="${vpc}" --query 'InternetGateways[].InternetGatewayId' --output text); do
    echo "Detaching internet gateway ${igw}"
    aws ec2 detach-internet-gateway --region "${region}" --internet-gateway-id "${igw}" --vpc-id "${vpc}" || true
    aws ec2 delete-internet-gateway --region "${region}" --internet-gateway-id "${igw}" || true
  done

  for attachment in $(aws ec2 describe-network-interfaces --region "${region}" --filters Name=vpc-id,Values="${vpc}" --query 'NetworkInterfaces[].Attachment.AttachmentId' --output text); do
    [[ -z "${attachment}" || "${attachment}" == "None" ]] && continue
    echo "Detaching network interface attachment ${attachment}"
    aws ec2 detach-network-interface --region "${region}" --attachment-id "${attachment}" --force || true
  done

  for eni in $(aws ec2 describe-network-interfaces --region "${region}" --filters Name=vpc-id,Values="${vpc}" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text); do
    echo "Deleting network interface ${eni}"
    aws ec2 delete-network-interface --region "${region}" --network-interface-id "${eni}" || true
  done

  for subnet in $(aws ec2 describe-subnets --region "${region}" --filters Name=vpc-id,Values="${vpc}" --query 'Subnets[].SubnetId' --output text); do
    echo "Deleting subnet ${subnet}"
    aws ec2 delete-subnet --region "${region}" --subnet-id "${subnet}" || true
  done

  for rtb in $(aws ec2 describe-route-tables --region "${region}" --filters Name=vpc-id,Values="${vpc}" --query 'RouteTables[].RouteTableId' --output text); do
    for assoc in $(aws ec2 describe-route-tables --region "${region}" --route-table-ids "${rtb}" --query 'RouteTables[].Associations[?Main!=`true`].RouteTableAssociationId' --output text); do
      aws ec2 disassociate-route-table --region "${region}" --association-id "${assoc}" || true
    done
    aws ec2 delete-route-table --region "${region}" --route-table-id "${rtb}" || true
  done

  for sg in $(aws ec2 describe-security-groups --region "${region}" --filters Name=vpc-id,Values="${vpc}" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text); do
    echo "Clearing security group ${sg}"
    local ingress egress
    ingress="$(mktemp)"
    egress="$(mktemp)"
    aws ec2 describe-security-groups --region "${region}" --group-ids "${sg}" --query 'SecurityGroups[0].IpPermissions' --output json >"${ingress}" || true
    aws ec2 describe-security-groups --region "${region}" --group-ids "${sg}" --query 'SecurityGroups[0].IpPermissionsEgress' --output json >"${egress}" || true
    aws ec2 revoke-security-group-ingress --region "${region}" --group-id "${sg}" --ip-permissions "file://${ingress}" >/dev/null 2>&1 || true
    aws ec2 revoke-security-group-egress --region "${region}" --group-id "${sg}" --ip-permissions "file://${egress}" >/dev/null 2>&1 || true
    rm -f "${ingress}" "${egress}"
    aws ec2 delete-security-group --region "${region}" --group-id "${sg}" || true
  done
}

vpcs="$(aws ec2 describe-vpcs --region "${region}" --filters Name=tag:Name,Values=staging-main --query 'Vpcs[].VpcId' --output text)"
for vpc in ${vpcs}; do
  attempt=1
  while [[ "${attempt}" -le 6 ]]; do
    sweep_vpc "${vpc}"
    if aws ec2 delete-vpc --region "${region}" --vpc-id "${vpc}"; then
      echo "Deleted ${vpc}"
      break
    fi
    echo "Dependencies still in ${vpc} after attempt ${attempt}:"
    aws ec2 describe-subnets --region "${region}" --filters Name=vpc-id,Values="${vpc}" --query 'Subnets[].SubnetId' --output text || true
    aws ec2 describe-network-interfaces --region "${region}" --filters Name=vpc-id,Values="${vpc}" --query 'NetworkInterfaces[].[NetworkInterfaceId,Status,Description]' --output text || true
    aws ec2 describe-security-groups --region "${region}" --filters Name=vpc-id,Values="${vpc}" --query 'SecurityGroups[?GroupName!=`default`].[GroupId,GroupName]' --output text || true
    aws ec2 describe-internet-gateways --region "${region}" --filters Name=attachment.vpc-id,Values="${vpc}" --query 'InternetGateways[].InternetGatewayId' --output text || true
    aws ec2 describe-vpc-endpoints --region "${region}" --filters Name=vpc-id,Values="${vpc}" --query 'VpcEndpoints[].VpcEndpointId' --output text || true
    attempt=$((attempt + 1))
    sleep 20
  done
done
