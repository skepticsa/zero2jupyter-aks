<#

As preresquisite: 
1. you needd to run the following command to generate a public/private pair.

    ssh-keygen -f ssh-key-jhubcluster

2. If you use Windows P{oweshell ISE, do not forget to change the current directory to the folder that contains this ps1 file.


3. Set the variables to your preferred values, e.g. region, vnet name, etc.

#>


$startMs = Get-Date
# -------------------------------------------------------------

clear

# https://zero-to-jupyterhub.readthedocs.io/en/latest/
# https://zero-to-jupyterhub.readthedocs.io/en/latest/kubernetes/microsoft/step-zero-azure.html

# az login

$LOCATION = 'centralus'
$RG = 'rg-jupyterhub'
$VNET = 'vnet-jupyterhub'
$SUBNET = 'subnet-jupyterhub'
$SERVICE_PRINCIPAL = 'binderhub-sp'

Write-Host "`n1. Creating Resource Group"
az group create `
   --name=$RG `
   --location=$LOCATION `
   --output table


Write-Host "`n2. Creating VNET"
az network vnet create `
   --resource-group $RG `
   --name $VNET `
   --address-prefixes 10.0.0.0/8 `
   --subnet-name $SUBNET `
   --subnet-prefix 10.240.0.0/16

Write-Host "`n3. Get VNET Id"
$VNET_ID=$(az network vnet show `
   --resource-group $RG `
   --name $VNET `
   --query id `
   --output tsv)
$VNET_ID

Write-Host "`n4. Get SubNet Id"
$SUBNET_ID=$(az network vnet subnet show `
   --resource-group $RG `
   --vnet-name $VNET `
   --name $SUBNET `
   --query id `
   --output tsv)
$SUBNET_ID


# We will create an Azure Active Directory (Azure AD) service principal for use with the cluster, 
# and assign the Contributor role for use with the VNet. Make sure SERVICE-PRINCIPAL-NAME is something recognisable, for example, binderhub-sp.

Write-Host "`n5. az ad sp create-for-rbac and get password"
$SP_PASSWD=$(az ad sp create-for-rbac `
   --name $SERVICE_PRINCIPAL `
   --role Contributor `
   --scopes $VNET_ID `
   --query password  `
   --output tsv)
$SP_PASSWD

# https://markheath.net/post/create-service-principal-azure-cli

Write-Host "`n6. Get objectId"
$SP_OBJID=$(az ad app list --display-name $SERVICE_PRINCIPAL --query "[].objectId" -o tsv)
$SP_OBJID


Write-Host "`n7. Get appId"
$SP_ID=$(az ad app list --display-name $SERVICE_PRINCIPAL --query "[].appId" -o tsv)
$SP_ID

# -------------------------------------------------------------

# The following command will request a Kubernetes cluster within the resource group that we created earlier.


$CLUSTER_NAME = 'jhubcluster'
$SSH_FILE_NAME = '.\ssh-key-'  + $CLUSTER_NAME + '.pub'

# https://docs.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-create

Write-Host "`n8. Create Kubernetes cluster"
az aks create `
   --name $CLUSTER_NAME `
   --resource-group $RG `
   --ssh-key-value $SSH_FILE_NAME `
   --node-count 3 `
   --node-vm-size Standard_D2s_v3 `
   --service-principal $SP_ID `
   --client-secret $SP_PASSWD `
   --dns-service-ip 10.0.0.10 `
   --docker-bridge-address 172.17.0.1/16 `
   --network-plugin azure `
   --network-policy azure `
   --service-cidr 10.0.0.0/16 `
   --vnet-subnet-id $SUBNET_ID `
   --output jsonc # table

# az aks install-cli

#  %USERPROFILE%\.kube\config
Write-Host "`n9. Get Kubernetes credentials"
az aks get-credentials `
   --name $CLUSTER_NAME `
   --resource-group $RG `
   --output table

Write-Host "`n10. Get Kubernetes node"
kubectl get node


# Get-Location

# -------------------------------------------------------------
$endMs = Get-Date
$tookMs = ($endMs - $startMs).TotalMilliseconds

$tookMs

# Calculate elapsed time, usually it takes about
Write-Host "This script took $tookMs ms"

<#
Goto :END

$startMs = Get-Date
az ad sp delete --id $SP_ID
az group delete -n $RG -y

kubectl config delete-context $CLUSTER_NAME

$endMs = Get-Date

$tookMs = ($endMs - $startMs).TotalMilliseconds

# Calculate elapsed time, usually it takes about
Write-Host "DELETE took $tookMs ms"

:END

#>
