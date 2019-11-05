# Program to extend the hard disk of a vm
# ** Does not create a hard disk, it simply extends the existing volume **
#
# Author: Jason Crandall


param (
    $DiskSize,
    $VM_Name,
    $Server
)
$main = {
    # Connect to VCenter
    if ($global:DefaultVIServers.count -ne 1 -or $global:DefaultVIServers[0].name -ne $Server) {
        Connect-VIServer -Server $Server > $null 2>&1
    }

    Write-Host "-- Attached to " + $Server

    $VM = Get-VM $VM_Name

    if (($DiskSize) -and ($OsType -like 'windows')) {
        Write-Host "-- Setting disk size"
        extendWindowsDisk -DiskSize $DiskSize -VM $VM
    }

    else { 
        Write-Host "Missing or incomplete paramater`n`nExample: -DiskSize 100 -OsType windows -VM_Name virtual_machine`n" 
    }
}

function extendWindowsDisk {
    param (
        $DiskSize,
        $VM
    )
    $HD = Get-HardDisk -VM $VM
    Set-HardDisk -HardDisk $HD -CapacityGB $DiskSize -Confirm:$false
    if ($VM.PowerState -like 'PoweredOff') {
        Start-VM -VM $VM -Confirm:$false > $null 2>&1
    }
    $pass = Read-Host -AsSecureString -Prompt 'Enter the Administrator password'
    Invoke-VMScript -VM $VM -GuestUser Administrator -GuestPassword $pass -ScriptText {
        $size = Get-PartitionSupportedSize -DriveLetter C 
        Resize-Partition -DriveLetter C -Size $size.SizeMax
    }
}

&$main