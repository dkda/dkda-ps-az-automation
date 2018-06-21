<#
    .DESCRIPTION
        Runbooks to start or stop VMs on a Schedule using the Run As Account (Service Principal)

    .NOTES
        AUTHOR: Praveen Chamarthi / Ben Parry
        LASTEDIT: June 20, 2018
#>
Param(

    [Parameter(Mandatory=$true)]
    [String]$ResourceGroupName,

    [String]$ConnectionName = "AzureRunAsConnection",

    [Parameter(Mandatory=$true)]
    [ValidateSet("start", "stop")]
    [String]$Action

)

# Virtual Machines with this tag key/value pair will be started
# $tagName = "powerschedule"
# $tagValue = "officehours"

$tagName = "test"
$tagValue = "true"

try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Get all VMs with 'powerschedule=officehours' tag
$VirtualMachines = Get-AzureRmResource -TagName $tagName -TagValue $tagValue -ResourceType Microsoft.Compute/virtualMachines

foreach($VirtualMachine in $VirtualMachines){

  $VmName = $VirtualMachine.Name

  switch ($Action){
    "stop" {
      Write-Output "Stopping $VmName ..."
      $Status = $VirtualMachine | Stop-AzureRmVM -Force
    }
    "start" {
      Write-Output "Starting $VmName ..."
      $Status = $VirtualMachine | Start-AzureRmVM
    }
  }

  $Status

  if($Status.StatusCode -eq 'OK')
  {
      Write-Output "-- $Action of $VmName successful"
      
  }else{
      Write-Output "-- $Action of $VmName failed"
      $Status.ReasonCode
  }

}
