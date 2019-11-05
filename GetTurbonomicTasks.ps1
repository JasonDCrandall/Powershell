# A program designed to make an API call to turbonomic to get a list of VM's whose Memory
# can be optimized. It takes the suggested modification of memory, and if the suggested is 
# over half the current size, will modify it to be half of the current usage.
#
# Author: Jason Crandall


param (
    $UuidUrl,
    $TaskUrl
)

$main = {
    # Variable declarations:
    $cred = Get-Credential -Message 'Enter your credentials for turbonomic:'
    $taskTable = @{ }

    # API call to turbonomic to get the uuid's of all of the vm's currently in the marketplace
    try {
        $uuidApiUrl = $ApiUrl
        $uuidApiCall = Invoke-RestMethod -Method 'Get' -Uri $uuidApiUrl -Credential $cred -Authentication Basic -SkipCertificateCheck
    }
    catch {
        Write-Host "Error making call to turbonomic for uuid's.`nMake sure your username and password are correct."
        exit
    }

    $uuidList = (($uuidApiCall).target).uuid

    Write-Host "--- Fetching tasks"

    for ($i = 0; $i -lt $uuidList.Count; $i++) {
        # API call to get the name of the vm and a list of all of its pending tasks from the uuid list
        try {
            $tasksApiUrl = $TaskUrl"$($uuidList[$i])/actions?order_by=severity&ascending=true"
            $tasksApiCall = Invoke-RestMethod -Method 'Get' -Uri $tasksApiUrl -Credential $cred -Authentication Basic -SkipCertificateCheck
        }
        catch {
            Write-Host "Error making call to turbonomic for tasks"
            exit
        }
        $taskList = $tasksApiCall.details
        $vm = ($tasksApiCall.target[0]).displayName
        parseTaskApi -vm $vm -hashTable $taskTable -taskList $taskList
    }
    # Display the vm with its 'scale down' task
    $taskTable
}

# Function to parse through turbonomic action api calls to store only the 
# valid tasks. Takes a vm, the tasks for that vm, and a hash table as a parameter.
# If the task is a scale down memory task with a difference greater than 8 GB, it
# adds that vm and formatted task to the inputted hash table.
function parseTaskApi {
    param (
        $vm,
        $taskList,
        $hashTable
    )
    foreach ($task in $taskList) {
        if ($task.subString(0, 15) -like "Scale down VMem") {
            $difference = getMemDifference($task)
            if (($difference -ge 8)) {
                $formattedTask = formatTask($task)
                try {
                    $hashTable.Add($vm, $formattedTask)
                }
                catch {
                    continue
                }  
            } 
        }
    }
}

# Function to obtain the difference in GB from a 'Scale down VMem task
# from turbonomic. Takes in the task as a parameter and returns the difference
# as an integer.
function getMemDifference {
    param (
        $task
    )
    $mem = [regex]::Matches($task, "\d+(\.\d+)?").value
    $difference = ($mem[$mem.Count - 2] - $mem[$mem.Count - 1])
    return $difference
}

# Function to reformat a valid turbonomic task. It will first check if the suggested
# is more than half of the original memory, if so, it returns the original task. If the 
# suggested is less than half the original memory, it will reformat the task and replace
# the suggested with half of the original memory.
function formatTask {
    param (
        $task
    )
    $regex = [regex]::Matches($task, "\d+(\.\d+)?").value
    $initialMem = $regex[$regex.Count - 2]
    $suggestedMem = $regex[$regex.Count - 1]
    $difference = $initialMem - $suggestedMem

    if (($difference) -lt ($initialMem / 2)) {
        return $task
    }
    else {
        $newSuggestedMem = [Math]::Floor($initialMem / 2)
        $formattedTask = $task -replace " $($suggestedMem) GB", " $($newSuggestedMem) GB"
        return $formattedTask
    }
}

&$main