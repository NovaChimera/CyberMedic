function Invoke-cybermedicIpc {
    param(
        [Parameter(Mandatory)] [string]$Task,
        [hashtable]$Arguments = @{}
    )
    $switches = @()
    switch ($Task) {
        'Install' { $switches += '-Install' }
        'Uninstall' { $switches += '-Uninstall' }
        'Update' { $switches += '-Update' }
        default { $switches += "-$Task" }
    }
    foreach ($k in $Arguments.Keys) {
        $switches += "-$k"
        $switches += "$($Arguments[$k])"
    }
    return $switches
}

$script:cybermedicIpcBridge = $true

