# SetESXRootPassword.ps1
#
# Used to change or reset the root password on all hosts in an ESX Cluster
#
# Requires PowerCLI
# non tested on PowerShell 7
# Works on vSphere 6.0 or later
#
# If not using trusted certificate on vCenter - may need to SetPowerCLI-Configuration -InvalidCertificateAction $false

if ($global:DefaultVIServers.count -ne 0) {   
    write-host "PowerCLI vCenter connections detected.  Disconnecting..."
    disconnect-viserver -server * -confirm:$false
}

$VCServer = Read-Host -Prompt "Enter your vCenter Server (vcenter.foo.org)"
$VCUser = Read-host -Prompt "Enter vCenter user with Administrator rights (user@foo.org)"
$VCUserCred = Get-Credential -UserName "$VCUser" -Message "Enter your vCenter Password."

Try { 
    Write-Host "Connecting to vCenter server at $VCServer...  " -NoNewline
    $vCenter = connect-viserver -Server $VCServer -Credential $VCUserCred -ErrorAction Stop
    Write-host "Connected!"
}
Catch {
    write-host -ForegroundColor Red "`n`nUnable to Connect to $VCServer using $VCUser.  Exiting`n"
    break
}

$Clusters = get-cluster
if ($clusters -eq 0) {
    write-host "`nNo clusters found. Exiting`n"
    exit
}

Write-Host "`nThe following clusters were found:"
$Clusters.name

$TargetClusterName = Read-Host -prompt "`nEnter the name of the cluster for root host password change"

$ConfirmCluster = $Clusters.Name 
if ($ConfirmCluster -notContains $TargetClusterName) {
    write-host -ForegroundColor Red "`nThe specified cluster ($TargetClusterName) does not exist.  Exiting`n"
    exit
}

try {
    $TargetHosts = get-vmhost -Location $TargetClusterName
}
Catch {
    write-host -ForegroundColor Red "`nUnable to retrieve hosts in the specified cluster ($TargetCluster).  Exiting`n"
    exit
}

$cred = Get-Credential -UserName "root" -message "Enter new ESXi root password"

Write-host "`nA new root password will be set on the following ESXi hosts:"
$TargetHosts.Name

$foo = read-host -prompt "`nPress enter to continue.  CTL-C to exit`n"

foreach ($ESXHost in $TargetHosts) {
    Write-host "Setting root password for $ESXHost  " -NoNewline
    $esxcli = get-esxcli -vmhost $ESXHost -v2 
    $esxcli.system.account.set.Invoke(@{id=$cred.UserName;password=$cred.GetNetworkCredential().Password;passwordconfirmation=$cred.GetNetworkCredential().Password})
}

disconnect-viserver $vCenter -Confirm:$false