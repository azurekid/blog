<#
.SYNOPSIS
Checks the apiVersion per resource defined in an ARM template.

.DESCRIPTION
Iterates through all json ARM templates in the defined location and validates if the
latest version of the resource API is used to identify technical dept.

.PARAMETER FilesPath
The path in which (sub)folders will be scanned for ARM templates

.PARAMETER Preview
Switch to exclude the preview versions of the API's

.OUTPUTS
None
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [String] $FilesPath,
    
    [Parameter(Mandatory = $false)]
    [bool] $Preview
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$templateFiles = @()
$resourcesProviders = Get-AzResourceProvider

Function Get-ApiVersion ($ProviderNamespace, $ResourceType) {
    try {
        if ($ProviderNamespace -eq "providers" `
                -and $ResourceType `
                -eq "locks") {
            
            $ProviderNamespace = "Microsoft.Authorization"
        }
        if ($ProviderNamespace -eq "providers" `
                -and $ResourceType `
                -eq "diagnosticSettings") {
            
            $ProviderNamespace = "Microsoft.Insights"
        }

        $LatestAPI = ((($resourcesProviders | Where-Object { $_.ProviderNamespace -eq $ProviderNamespace }).ResourceTypes `
                | Where-Object { $_.ResourceTypeName -eq $ResourceType }).ApiVersions `
                | Sort-Object -Descending)
        
            if (!($Preview)) {
                $API = ($LatestAPI | Sort-Object -Descending)[0]
            }
            else {
                $API = ($LatestAPI | Where-Object { $_ -notlike "*preview*" } `
                    | Sort-Object -Descending)[0]
            }
            
            Write-Host "Latest API version is: " $API
            Return $API
    }
    catch {
        
    }
}

$templateFiles = @(Get-ChildItem -Path $FilesPath `
        -Recurse `
        -Filter "*.json" | `
        Where-Object { $_.name -notmatch ".parameters" `
            -and $_.name `
            -notmatch ".config" })

if ($templateFiles) {
    $fileCounter = 1
    ForEach ($templateFile In $templateFiles) {
        Write-Output " Processing ARM template $fileCounter/$($templateFiles.Count) with name '$($templateFile.Name)'."
        $fileCounter++
    
        Get-Content -Path $templateFile.FullName | ConvertFrom-Json | `
            Select-Object -ExpandProperty "resources" | `
            ForEach-Object {
            $typeArray = ($_.type) -Split ('/'), 2
            
            Write-Output "Primary resource:" $_.type
            Write-Output "Current API version: " $_.apiVersion

            $LatestAPI = Get-ApiVersion -ProviderNamespace $typeArray[0] `
                -ResourceType $typeArray[1]

            Write-Verbose "Entering Microsoft Resources Section"
            
            try {
                if ($_.type -eq "Microsoft.Resources/deployments") {
                    if ($_.properties.template.resources) {
                        foreach ($subresource in $_.properties.template.resources) {
                            $typeArray = ($subresource.type) -Split ('/'), 2
                                
                            Write-Output "Secondary resource: " $subresource.type 
                            Write-Output "Current API version" $subresource.apiVersion 
                                                        
                            $LatestAPI = Get-ApiVersion -ProviderNamespace $typeArray[0] -ResourceType $typeArray[1]
                        }
                    }
                }    
            }
            catch {
                Write-Output "No API version found"
         }

            Write-Verbose "Entering Sub Resources Section"
            try {
                if ($_.resources) {
                    foreach ($subresource in $_.resources) {
                        $typeArray = ($subresource.type) -Split ('/'), 2
                        
                        Write-Output "Secondary Sub resource: " $subresource.type 
                        Write-Output "Current API version" $subresource.apiVersion 
                            
                        $LatestAPI = Get-ApiVersion -ProviderNamespace $typeArray[0] -ResourceType $typeArray[1]
                    }
                }    
            }
            catch {
                Write-Output "No Sub Resources found"
            }            
        }   
    }    
}