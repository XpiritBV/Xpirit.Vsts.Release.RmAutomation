#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

Param(
    [string] $ResourceGroupName,        
	[string] $AutomationAccount,
	[string] $TemplateFile,
	[string] $VariableFiles 
)

Import-Module Azure -ErrorAction SilentlyContinue

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(" ","_"), "2.8")
} catch { }

Set-StrictMode -Version 3  

Write-Output "Deploying the following Variable Files $VariableFiles"

[string[]] $VariableFilesSplit = $VariableFiles -split ';|\r?\n'

$ProjectPath = [System.IO.Path]::Combine($env:SYSTEM_ARTIFACTSDIRECTORY,$env:BUILD_DEFINITIONNAME,"drop")

$TemplateFile = [System.IO.Path]::Combine($PSScriptRoot, $TemplateFile)

Foreach ($file in $VariableFilesSplit){
    if ($file){
		$VariablesPath  =  [System.IO.Path]::Combine($ProjectPath, $file)
		$Variables = Get-Content -Raw -Path $VariablesPath | ConvertFrom-Json 

		foreach  ($var in $Variables.variables){
			New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
									-ResourceGroupName $ResourceGroupName `
									-TemplateFile $TemplateFile -TemplateParameterObject  @{accountName=$AutomationAccount;variableName=$var.name;variableType="string";variableValue=$var.value} -Force -Verbose
		}
	}
}


Write-Output "Finished deployment of variables to AutomationAccount: $AutomationAccount"