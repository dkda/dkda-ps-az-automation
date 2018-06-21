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
    [String]$Action,

    [ValidateSet("true", "false")]
    [String]$RunOnWeekends = "false"
)

# Virtual Machines with this tag key/value pair will be stopped / started
$tagName = "powerschedule"
$tagValue = "officehours"

# If it's the weekend, exit
if ($RunOnWeekends -eq "false"){
    $day = (Get-Date).DayOfWeek
    if ($day -eq 'Saturday' -or $day -eq 'Sunday'){
        exit
    }
}


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

# I would use this implementation but apparently the AzureRM module they are running is from the 1960's
#$VirtualMachines = Get-AzureRmResource -TagName $tagName -TagValue $tagValue -ResourceType Microsoft.Compute/virtualMachines

$VirtualMachines = Find-AzureRmResource -TagName $tagName -TagValue $tagValue | Where-Object {$_.ResourceType -eq "Microsoft.Compute/virtualMachines"}

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