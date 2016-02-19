[CmdletBinding(DefaultParameterSetName = 'None')]
Param(
    [String] [Parameter(Mandatory = $true)] $ConnectedServiceName,  

    [string] $ResourceGroupName ,
	[string] $RegionId ,
	[string] $AutomationAccount ,
	[string] $VariableFiles
)

Import-Module Azure #-ErrorAction SilentlyContinue

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(" ","_"), "2.8")
} catch { }

Set-StrictMode -Version 3

$VariablesTemplateFile = 'Templates\deployVariable.json'
$RunbooksTemplateFile = 'Templates\deployPublishedRunbook.json'
$ModuleTemplateFile= 'Templates\deployModule.json'

$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDirectory = (Split-Path $ScriptPath -Parent)
$ProjectPath = [System.IO.Path]::Combine($env:SYSTEM_ARTIFACTSDIRECTORY,$env:BUILD_DEFINITIONNAME,"drop")

[string] $StorageAccountName = "automationdeploy" + ([guid]::NewGuid().ToString().Split("-")[0])
[string] $StorageContainerName = "automationdeploy"
	
Write-Output "Starting deployment of Automated Provisioning to AutomationAccount: $AutomationAccount"

Write-Output "Create resourcegroup $ResourceGroupName"

Import-Module AzureRm.Resources

  New-AzureRmResourceGroup -Name $ResourceGroupName -Location $RegionId -Force

Write-Output "Create blob storage account: $StorageAccountName"

New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Location $RegionId -StorageAccountName $StorageAccountName -Type "Standard_LRS" 
[string] $StorageAccountKey = Get-AzureRmStorageAccountKey -Name $StorageAccountName -ResourceGroupName $ResourceGroupName | %{ $_.Key1 } 

Write-Output "Copy files in blobstorage container $StorageContainerName"
$SourceContext = (Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).Context

New-AzureStorageContainer -Context $SourceContext -Container $StorageContainerName -Permission Blob

get-childitem $ProjectPath -recurse | where {$_.extension -eq ".ps1"} | % {
	$fullname =  $_.FullName
    Write-Host "Upload blob file $fullname"
    Set-AzureStorageBlobContent  -Context $SourceContext -Container $StorageContainerName  -File $fullname -Blob $fullname.Substring(3).Replace(" ","")
}

get-childitem $ProjectPath -recurse | where {$_.extension -eq ".zip"} | % {
    $fullname =  $_.FullName
    Write-Host "Upload blob file $fullname"
    Set-AzureStorageBlobContent  -Context $SourceContext -Container $StorageContainerName  -File $fullname -Blob $fullname.Substring(3).Replace(" ","")
}

Write-Output "Create automation account -Name $AutomationAccount -Location $RegionId -ResourceGroupName $ResourceGroupName"

New-AzureRmAutomationAccount -Name $AutomationAccount -Location $RegionId -ResourceGroupName $ResourceGroupName 

$scriptPath = (Join-Path -Path $ScriptDirectory -ChildPath "Deploy-BlobStorageVariables.ps1")
Invoke-Expression "& `"$ScriptPath`" -ResourceGroupName $ResourceGroupName -AutomationAccount $AutomationAccount -TemplateFile $VariablesTemplateFile -VariableFiles `"$VariableFiles`"" 

$scriptPath = (Join-Path -Path $ScriptDirectory -ChildPath "Deploy-BlobStorageRunbooks.ps1")
Invoke-Expression "& `"$ScriptPath`" -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -StorageContainerName $StorageContainerName -StorageAccountKey $StorageAccountKey -AutomationAccount $AutomationAccount -RegionId `"$RegionId`" -TemplateFile $RunbooksTemplateFile"

$scriptPath = (Join-Path -Path $ScriptDirectory -ChildPath "Deploy-BlobStorageModules.ps1")
Invoke-Expression "& `"$ScriptPath`" -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -StorageContainerName $StorageContainerName -StorageAccountKey $StorageAccountKey -AutomationAccount $AutomationAccount  -TemplateFile $ModuleTemplateFile"

#remove blob strorage account
Write-Output "Remove storage account $StorageAccountName resourcegroupname $ResourceGroupName"

Get-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName | Remove-AzureRmStorageAccount 

Write-Output "Finished deployment of Automated Provisioning to AutomationAccount: $AutomationAccount"

