function Log-Message {
    param (
        [string]$Message,
        [string]$LogFile,
        [switch]$Verbose
    )
    
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $Message
    }
    if ($Verbose) {
        Write-Verbose $Message
    } else {
        Write-Host $Message
    }
}

# Execute a function with a simple log message
Log-Message -Message "This is a log message." -Verbose:$true