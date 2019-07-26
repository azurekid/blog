<#
.SYNOPSIS
    Create's an Azure DevOps Project within a specified organization.

.SYNTAX
    Create-DevOpsProject [-Organization <String>] [-ProjectName <String>] [-AzureAdGroup <String>] -Process <String> -Visibility <String>

.DESCRIPTION
    This script will create an Azure DevOps Project in an existing organization and adds an Azure AAD group to the DevOps Security group Contributors. 

.PARAMETER Organization <String>
    Specifies the name of the Azure DevOps organization.

.PARAMETER ProjectName <String>
    Specifies the name of an Azure DevOps Project Name.

.PARAMETER AzureAdGroup <String>
    The name of the Azure AD Group used to add to the specified security group.

.PARAMETER Process <String>
    The Work item process used within the newly created project.

.PARAMETER Visibility <String>
    Specifies the visibility of the project to other organization members
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [String]$Organization = "",

    [Parameter(Mandatory = $true)]
    [String]$ProjectName = "",
    
    [Parameter(Mandatory = $true)]
    [String]$AzureAdGroup,

    [Parameter(Mandatory = $true)]
    [String]$SecurityGroup,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Scrum", "Agile", "Basic", "CMMI")]
    [String]$Process = "Scrum",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Git", "Tfvc")]
    [String]$SourceControl = "Git",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Private", "Public")]
    [String]$Visibility = "Private"
)

Set-StrictMode -Version 'Latest'
$ErrorActionPreference = 'Stop'

Write-Verbose "Organization      : $($Organization)"
Write-Verbose "ProjectName       : $($ProjectName)"
Write-Verbose "Azure Ad Group    : $($AzureAdGroup)"
Write-Verbose "DevOps Group      : $($SecurityGroup)" 
Write-Verbose "Process           : $($Process)"
Write-Verbose "Source Control    : $($SourceControl)"
Write-Verbose "Visibility        : $($Visibility)"

$endpoint = "https://dev.azure.com/$Organization"

    $result = az devops project create --name $ProjectName `
                             --org $endpoint `
                             --process $process `
                             --source-control $SourceControl `
                             --visibility $Visibility `
                             | ConvertTo-Json
if($result) {
    Write-Output "Azure DevOps project with name [$($ProjectName)] has been created succesfully"
}
    
$devOpsGroups = (az devops security group list --org $endpoint `
                                    --project $ProjectName) `
                                    | ConvertFrom-Json `
                                    | Select-Object -ExpandProperty "graphGroups"

try {
    $devOpsGroupId = ($devOpsGroups | Where-Object {$_.displayname -eq $SecurityGroup}).descriptor
}
catch {
    Write-Error "The Azure DevOps Security Group [$($SecurityGroup)] could not be found"
}
    
if($devOpsGroupId){
    try {
        az devops security group create --origin-id ((Get-AzADGroup -DisplayName $AzureAdGroup).id) `
                            --groups $DevOpsGroupId `
                            --org $endpoint `
                            --scope organization `
                            --output none
    }
    catch {
        Write-Output "WARNING: The Azure DevOps Security Group [$($SecurityGroup)] could not be updated"
        return
    }

    Write-Output "Azure AD Group [$($AzureAdGroup)] has been added to Security Group [$($SecurityGroup)]"
}