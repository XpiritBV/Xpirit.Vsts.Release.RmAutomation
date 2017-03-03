[CmdletBinding(DefaultParameterSetName = 'None')]
Param(
    [String] [Parameter(Mandatory = $true)] $ConnectedServiceNameSelector,    
    [String] $ConnectedServiceName,
    [String] $ConnectedServiceNameARM, 

    [string] $ResourceGroupName ,
	[string] $RegionId ,
	[string] $AutomationAccount ,
	[string] $VariableFiles,
	[string] $RunbookFiles,
	[string] $ModuleFiles

)

Import-Module Azure #-ErrorAction SilentlyContinue

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(" ","_"), "2.8")
} catch { }

Set-StrictMode -Version 3

#$SchedulesTemplateFile = 'Templates\deploySchedule.json'
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

New-AzureRmResourceGroup -Name $ResourceGroupName -Location $RegionId -Force | Out-Null

Write-Output "Create blob storage account: $StorageAccountName"

New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Location $RegionId -StorageAccountName $StorageAccountName -Type "Standard_LRS" 
[string] $StorageAccountKey = Get-AzureRmStorageAccountKey -Name $StorageAccountName -ResourceGroupName $ResourceGroupName | %{ $_.Value[0] } 

Write-Output "Copy files in blobstorage container $StorageContainerName"
$SourceContext = (Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).Context

New-AzureStorageContainer -Context $SourceContext -Container $StorageContainerName -Permission Blob

if ($RunbookFiles){
	[string[]] $RunbookFilesSplit = $RunbookFiles -split ';|\r?\n'
	foreach($RunbookFile in $RunbookFilesSplit)
	{
		if ($RunbookFile)
		{
		    $searchPath = [System.IO.Path]::Combine($ProjectPath, $RunbookFile)
			get-childitem $searchPath -recurse | where {$_.extension -eq ".ps1"} | % {
				$fullname =  $_.FullName
				Write-Host "Upload blob file $fullname"
				Set-AzureStorageBlobContent  -Context $SourceContext -Container $StorageContainerName  -File $fullname -Blob $fullname.Substring(3).Replace(" ","")
			}
		}
    }
}
else
{
	get-childitem $ProjectPath -recurse | where {$_.extension -eq ".ps1"} | % {
		$fullname =  $_.FullName
		Write-Host "Upload blob file $fullname"
		Set-AzureStorageBlobContent  -Context $SourceContext -Container $StorageContainerName  -File $fullname -Blob $fullname.Substring(3).Replace(" ","")
	}
}

if ($ModuleFiles)
{
    [string[]] $ModuleFilesSplit = $ModuleFiles -split ';|\r?\n'
	foreach($ModuleFile in $ModuleFilesSplit)
	{
		if ($ModuleFile)
		{
		    $searchPath = [System.IO.Path]::Combine($ProjectPath, $ModuleFile)
			get-childitem $searchPath -recurse | where {$_.extension -eq ".zip"} | % {
				$fullname =  $_.FullName
				Write-Host "Upload blob file $fullname"
				Set-AzureStorageBlobContent  -Context $SourceContext -Container $StorageContainerName  -File $fullname -Blob $fullname.Substring(3).Replace(" ","")
			}
		}
    }
}
else
{
	get-childitem $ProjectPath -recurse | where {$_.extension -eq ".zip"} | % {
		$fullname =  $_.FullName
		Write-Host "Upload blob file $fullname"
		Set-AzureStorageBlobContent  -Context $SourceContext -Container $StorageContainerName  -File $fullname -Blob $fullname.Substring(3).Replace(" ","")
	}
}

Write-Output "Create automation account -Name $AutomationAccount -Location $RegionId -ResourceGroupName $ResourceGroupName"

New-AzureRmAutomationAccount -Name $AutomationAccount -Location $RegionId -ResourceGroupName $ResourceGroupName 

$scriptPath = (Join-Path -Path $ScriptDirectory -ChildPath "Deploy-BlobStorageRunbooks.ps1")
Invoke-Expression "& `"$ScriptPath`" -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -StorageContainerName $StorageContainerName -StorageAccountKey $StorageAccountKey -AutomationAccount $AutomationAccount -RegionId `"$RegionId`" -TemplateFile $RunbooksTemplateFile" 

$scriptPath = (Join-Path -Path $ScriptDirectory -ChildPath "Deploy-BlobStorageModules.ps1")
Invoke-Expression "& `"$ScriptPath`" -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -StorageContainerName $StorageContainerName -StorageAccountKey $StorageAccountKey -AutomationAccount $AutomationAccount  -TemplateFile $ModuleTemplateFile" 

$scriptPath = (Join-Path -Path $ScriptDirectory -ChildPath "Deploy-BlobStorageVariables.ps1")
Invoke-Expression "& `"$ScriptPath`" -ResourceGroupName $ResourceGroupName -AutomationAccount $AutomationAccount -TemplateFile $VariablesTemplateFile -VariableFiles `"$VariableFiles`"" 

#$scriptPath = (Join-Path -Path $ScriptDirectory -ChildPath "Deploy-BlobStorageSchedules.ps1")
#Invoke-Expression "& `"$ScriptPath`" -ResourceGroupName $ResourceGroupName -AutomationAccount $AutomationAccount -TemplateFile $SchedulesTemplateFile -ScheduleFiles `"$ScheduleFiles`"" 

#remove blob strorage account
Write-Output "Remove storage account $StorageAccountName resourcegroupname $ResourceGroupName"

Get-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName | Remove-AzureRmStorageAccount 

Write-Output "Finished deployment of Automated Provisioning to AutomationAccount: $AutomationAccount"

