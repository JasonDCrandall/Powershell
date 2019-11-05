# This program reads from a csv file a list of source addresses and destination addresses
# and converts them to their DNS Hostnames.
#
# Author: Jason Crandall

param (
    $InPath,
    $OutPath
)

$main = {
    $doc = Import-Csv -Path $InPath
    $result = [System.Collections.ArrayList]@()

    $sourceAddresses = $doc.'Source address'
    $destinationAddresses = $doc.'Destination address'
    
    $sourceHostNames = convertIpAddressToHostName($sourceAddresses)
    $destinationHostNames = convertIpAddressToHostName($destinationAddresses)

    for ($i = 0; $i -lt $sourceHostNames.Count; $i++) {
        [void]$result.Add([PSCustomObject]@{
            'Source HostName' = $sourceHostNames[$i]
            'Destination HostName' = $destinationHostNames[$i]
        })
    }

    $result | Export-Csv -Path $OutPath
}

function convertIpAddressToHostName {
    param (
        $IpAddresses
    )
    $hostNames = [System.Collections.ArrayList]@()
    foreach ($address in $IpAddresses) {
        try {
            $name = ([System.Net.Dns]::GetHostByAddress($address)).HostName
            [void]$hostNames.Add($name)
        }
        catch {
            [void]$hostNames.Add($address + ' does not have a host name or times out from a ping request')
        }
    }
    return $hostNames
}

&$main