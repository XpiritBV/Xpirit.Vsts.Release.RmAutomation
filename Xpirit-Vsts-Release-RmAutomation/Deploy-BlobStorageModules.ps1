#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

Param(
    
    [string] $ResourceGroupName ,
	[string] $StorageAccountName,
	[string] $StorageContainerName,
	[string] $StorageAccountKey,	
	[string] $AutomationAccount ,
    [string] $TemplateFile
)
Import-Module Azure -ErrorAction SilentlyContinue

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(" ","_"), "2.8")
} catch { }

Set-StrictMode -Version 3

$TemplateFile = [System.IO.Path]::Combine($PSScriptRoot, $TemplateFile)

Write-Output "Going to deploy Modules to AutomationAccount: $AutomationAccount"

$SourceContext = (Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).Context

$blobs = Get-AzureStorageBlob -Container $StorageContainerName -Context $SourceContext

$insertorderblobs = New-Object System.Collections.ArrayList

foreach ($blobname in $blobs.Name){
    if ($blobname.EndsWith(".zip"))
    {
            $t = $insertorderblobs.Add($blobname)
    }
}


foreach ($item in $insertorderblobs)
{
	$Name = $item.Split('/')[$item.Split('/').Length-1].Split('.')[0].ToString()
	$ModuleURI = -join($SourceContext.BlobEndPoint, $StorageContainerName,"/", $item) 

	New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                            -ResourceGroupName $ResourceGroupName `
                            -TemplateFile $TemplateFile -TemplateParameterObject @{accountName=$AutomationAccount;moduleName=$Name;moduleURI=$ModuleURI} -Force -Verbose
	
}

Write-Output "Succesfully deployed Modules to AutomationAccount: $AutomationAccount"