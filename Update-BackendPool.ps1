<#
.SYNOPSIS
	Updates the Azure Load Balancer backend Pool

.DESCRIPTION
	Add's vm's to the backend pool of the specified Azure Load Balancer.

.OUTPUTS
	Progress messages
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $True)]
    [string]$loadBalancerName,
    [Parameter(Mandatory = $True)]
    [string]$resourceGroupName,
    [Parameter(Mandatory = $True)]
    [string]$debugDeploymentDebugLevel,
    [Parameter(Mandatory = $True)]
    [string]$availabilitySetName,
    [Parameter(Mandatory = $True)]
    [string]$backendPoolName
)

$ErrorActionPreference = "Stop"

Try {
    $loadBalancer = Get-AzureRmLoadBalancer `
        -Name $loadBalancerName `
        -ResourceGroupName $resourceGroupName `
        -ErrorAction Stop
}
Catch {
    Write-Warning "No Load Balancer found with name $loadBalancerName in resource group $resourceGroupName"
    Return
}

try {
    $backendPool = Get-AzureRmLoadBalancerBackendAddressPoolConfig `
        -Name $backendPoolName `
        -LoadBalancer $loadBalancer
}
catch {
    #Write-Warning "no Backend Pool found with the name $backendPoolName in the load balancer with the name $loadBalancerName"
    Return
}

try {
    $AvSet = Get-AzureRmAvailabilitySet `
        -Name $availabilitySetName `
        -ResourceGroupName (Get-AzureRmResource | Where-Object {
            ($_.Name -eq $availabilitySetName) -and `
            ($_.ResourceType -eq "Microsoft.Compute/AvailabilitySets")}).ResourceGroupName
}
catch {
    Write-Warning "no AvailabilitySet found with the name $availabilitySetName in resource group $availabilitySetResourceGroup"
    Return
}

ForEach ($id in $avSet.VirtualMachinesReferences.id) {

    $nic = Get-AzureRmNetworkInterface | Where-Object {($_.VirtualMachine.id).ToLower() -eq ($id).ToLower()}
    $nic.IpConfigurations[0].LoadBalancerBackendAddressPools = $backendPool

    Set-AzureRmNetworkInterface -NetworkInterface $nic -AsJob    
}    

If ($ErrorMessages) {
    Write-Error "Deployment returned the following errors: $ErrorMessages";
    Return
}