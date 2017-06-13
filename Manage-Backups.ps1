# User Configurable
$Servers=@('NS1','NS2','NS3','NS4','NS5','NS6')

# Nothing user configurable below this line
$thisdir=$PSScriptRoot
cd $thisdir
if (!(Get-Module -Name 'Posh-SSH')) {
    Copy-Item $thisdir\Posh-SSH -Destination (($env:PSModulePath.Split(';'))[0]) -Recurse -Force
}

Import-Module Posh-SSH

if (!$cred) {$cred=Get-Credential}

function Save-NSConfig {
    if (!$cred) {$cred=Get-Credential}
    $jobs=@()
    foreach ($Server in $Servers) {
        $jobs+=start-job -scriptblock {
            Import-module Posh-SSH; 
            $SshSession=New-SSHSession -ComputerName $using:Server -Credential $using:cred -AcceptKey 
            Invoke-SSHCommand -SSHSession $SshSession -Command 'save ns config' -Verbose
            Remove-SSHSession $SshSession
        }
    }
    $jobs|Wait-Job
    $jobs|Receive-Job

}

function Create-NSBackup {
    if (!$cred) {$cred=Get-Credential}
    $jobs=@()
    foreach ($Server in $Servers) {
        $jobs+=start-job -ScriptBlock {
            $session=New-SSHSession -ComputerName $using:Server -Credential $using:cred -AcceptKey
            Invoke-SSHCommand -Command 'save ns config' -SSHSession $session -Verbose
            Invoke-SSHCommand -Command 'create system backup -level full' -SSHSession $session -Verbose
            Remove-SSHSession $session
        }
    }
    $jobs|Wait-Job
    $jobs|Receive-Job
}

function Get-NSBackup {
    if (!$cred) {$cred=Get-Credential}
    foreach ($Server in $Servers) {
        $sftpsession=New-SFTPSession -ComputerName $Server -Credential $cred -AcceptKey
        $backupFiles=Get-SFTPChildItem -SFTPSession $sftpsession -Path '/var/ns_sys_backup' | Where-Object {$_.FullName -Like "*backup_full*"}|Sort-Object -Descending
        $backupFiles
        Get-SFTPFile -SFTPSession $sftpsession -RemoteFile $backupFiles[0].FullName -LocalPath $thisdir -Verbose
        Remove-SFTPSession $sftpsession
    }
}


Save-NSConfig
Create-NSBackup
Get-NSBackup
