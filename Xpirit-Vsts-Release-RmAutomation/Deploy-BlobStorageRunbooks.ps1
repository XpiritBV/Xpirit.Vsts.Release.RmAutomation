#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

Param(
  
    
	[string] $ResourceGroupName,
	[string] $StorageAccountName,
	[string] $StorageContainerName,
	[string] $StorageAccountKey,
	[string] $RegionId,
	[string] $AutomationAccount,
    [string] $TemplateFile
)
Import-Module Azure -ErrorAction SilentlyContinue

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(" ","_"), "2.8")
} catch { }

Set-StrictMode -Version 3

$TemplateFile = [System.IO.Path]::Combine($PSScriptRoot, $TemplateFile)

Write-Output "Starting deployment of Runbooks to AutomationAccount: $AutomationAccount"

$SourceContext = (Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).Context
	
$blobs = Get-AzureStorageBlob -Container $StorageContainerName -Context $SourceContext

$insertorderblobs = New-Object System.Collections.ArrayList  

if ($blobs)   
{
	for ( $i = 20; $i -ge 0;  $i--)
    {
		foreach ($blobname in $blobs){
			if ($blobname.Name.EndsWith(".ps1"))
			{
				if ($blobname.Name.Split('/').Length -eq $i)
				{
					$t = $insertorderblobs.Add($blobname.Name)
				}
			}
		}
	} 
}

Write-Output "Found the following files $insertorderblobs"

foreach ($item in $insertorderblobs)
{
	$Name = $item.Split('/')[$item.Split('/').Length-1].Split('.')[0].ToString()
	$RunbookURI = -join($SourceContext.BlobEndPoint, $StorageContainerName,"/", $item)

	New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                            -ResourceGroupName $ResourceGroupName `
                            -TemplateFile $TemplateFile -TemplateParameterObject  @{accountName=$AutomationAccount;regionId=$RegionId;runbookName=$Name;runbookURI=$RunbookURI;runbookType='Script';runbookDescription='Auto deploy'} -Force -Verbose
	
}

Write-Output "Finished deployment of Runbooks to AutomationAccount: $AutomationAccount"