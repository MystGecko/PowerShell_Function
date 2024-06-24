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
# Exécuter une fonction avec une log message simple
Log-Message -Message "Ceci est un message de journalisation." -Verbose:$true
