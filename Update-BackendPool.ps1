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
    [string]$backendPoolName,
    [Parameter(Mandatory = $False)]
    [string]$availabilitySetName,
    [Parameter(Mandatory = $False)]
    [array]$vmNames
)

$ErrorActionPreference = "Stop"

function add-vmToLoadBalancer($object, $type, $backendPool) {
    
    if ($type -eq "avSet") {
        ForEach ($id in $object.VirtualMachinesReferences.id) {
            add-nicToBackendPool -id $id -backendPool $backendPool
        }
    }
    
    elseif ($type -eq "vm") {
        add-nicToBackendPool -id $object.id -backendPool $backendPool
    }
    else {
        Write-Warning "no virtual machines found to add to the backend pool"
    }
}    

function add-nicToBackendPool($id, $backendPool) {
    $nic = Get-AzureRmNetworkInterface | Where-Object {($_.VirtualMachine.id).ToLower() -eq ($id).ToLower()}
    $nic.IpConfigurations[0].LoadBalancerBackendAddressPools = $backendPool

    Set-AzureRmNetworkInterface -NetworkInterface $nic -AsJob
}

Try {
    $loadBalancer = Get-AzureRmLoadBalancer `
        -Name $loadBalancerName `
        -ResourceGroupName $resourceGroupName
}
Catch {
    Write-Warning "No Load Balancer found with name: $loadBalancerName in resource group $resourceGroupName"
    Return
}

try {
    $backendPool = Get-AzureRmLoadBalancerBackendAddressPoolConfig `
        -Name $backendPoolName `
        -LoadBalancer $loadBalancer
}
catch {
    Write-Warning "no Backend Pool found with the name: $backendPoolName"
    Return
}

try {
    if ($vmNames) {
        foreach ($vmName in $vmNames) {
            $vm = Get-AzureRmVM -Name $vmName `
                -ResourceGroupName (Get-AzureRmResource | Where-Object {
                    ($_.Name -eq $vmName) -and `
                    ($_.ResourceType -eq "Microsoft.Compute/VirtualMachines")}).ResourceGroupName

            add-vmToLoadBalancer -object $vm -type "vm" -backendPool $backendPool
        }
    }
}
catch {
    Write-Warning "no virtual machine found"
}
try {
    if ($availabilitySetName) {
        $AvSet = Get-AzureRmAvailabilitySet `
            -Name $availabilitySetName `
            -ResourceGroupName (Get-AzureRmResource | Where-Object {
                ($_.Name -eq $availabilitySetName) -and `
                ($_.ResourceType -eq "Microsoft.Compute/AvailabilitySets")}).ResourceGroupName
                
        Write-host "adding servers in AvSet $($AvSet.Name) to the load balancer"
        add-vmToLoadBalancer -object $AvSet -type "avSet" -backendPool $backendPool
    }
}
catch {
    Write-Warning "no Availability Set found with the name: $availabilitySetName"
    Return
}

If ($ErrorMessages) {
    Write-Error "Deployment returned the following errors: $ErrorMessages";
    Return
}
