#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

Param(
    [string] $ResourceGroupName,        
	[string] $AutomationAccount,
	[string] $TemplateFile,
	[string] $ScheduleFiles 
)

Import-Module Azure -ErrorAction SilentlyContinue

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(" ","_"), "2.8")
} catch { }

Set-StrictMode -Version 3  

Write-Output "Deploying the following Schedules Files $ScheduleFiles"

[string[]] $ScheduleFilesSplit = $ScheduleFiles -split ';|\r?\n'

$ProjectPath = [System.IO.Path]::Combine($env:SYSTEM_ARTIFACTSDIRECTORY,$env:BUILD_DEFINITIONNAME,"drop")

$TemplateFile = [System.IO.Path]::Combine($PSScriptRoot, $TemplateFile)

Foreach ($file in $ScheduleFilesSplit){
    if ($file){
		$SchedulesPath  =  [System.IO.Path]::Combine($ProjectPath, $file)
		$Schedules = Get-Content -Raw -Path $SchedulesPath | ConvertFrom-Json 

		foreach  ($var in $Schedules.schedules){
	        Write-Output "Deploying variable $Name"	

			New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
									-ResourceGroupName $ResourceGroupName `
									-TemplateFile $TemplateFile -TemplateParameterObject  @{accountName=$AutomationAccount;scheduleName=$var.scheduleName;runbookName=$var.runbookName;startTime=$var.startTime;frequency=$var.frequency;interval=$var.interval;jobScheduleGuid=$var.jobScheduleGuid} -Force -Verbose | out-null

            Write-Output "Variable $Name deployed"	
		}
	}
}

Write-Output "Finished deployment of schedules to AutomationAccount: $AutomationAccount"