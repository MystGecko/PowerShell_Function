function Connect-SharePoint {
    param (
        [Parameter(Mandatory=$true, HelpMessage="Unique identifier in UUID format.")]
        [Alias("Id")]
        [ValidatePattern("^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$")]  # Validates the UUID format
        [string]$TenantID,

        [Parameter(Mandatory=$true, HelpMessage="Unique identifier in UUID format for the Azure application.")]
        [Alias("AppID")]
        [ValidatePattern("^[A-Fa-f0-9]{8}-[A-Fa0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$")]  # Validates the UUID format
        [string]$ClientID,

        [Parameter(Mandatory=$true, HelpMessage="Secret associated with the unique identifier of the Azure application.")]
        [Alias("Secret")]
        [string]$ClientSecret,

        [Parameter(Mandatory=$false, HelpMessage="Indicates if errors should be displayed.")]
        [switch]$VerboseLogging,

        [Parameter(Mandatory=$false, HelpMessage="Path of the log file.")]
        [ValidateScript({Test-Path (Split-Path $_ -Parent)})]  # Validates that the log folder exists
        [string]$LogFile
    )

    # Display parameters
    Log-Message "################# Connect-SharePoint #################" -Verbose:$VerboseLogging
    Log-Message "[+] TenantID: $TenantID" -Verbose:$VerboseLogging
    Log-Message "[+] ClientID: $ClientID" -Verbose:$VerboseLogging
    $maskedSecret = Mask-String -String $ClientSecret     
    Log-Message "[+] ClientSecret: $maskedSecret" -Verbose:$VerboseLogging

    # Token retrieval
    Log-Message "[-] Retrieving token in progress..." -Verbose:$VerboseLogging
    $graphApiUrl = "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token"
    Log-Message "[-] Graph API URL: $graphApiUrl" -Verbose:$VerboseLogging
    try {
        $response = Invoke-WebRequest -Uri $graphApiUrl -Method Post -Body @{
            grant_type = "client_credentials"
            client_id = $ClientID
            client_secret = $ClientSecret
            scope = 'https://graph.microsoft.com/.default'
        }
        Log-Message "[+] Token retrieval successful" -Verbose:$VerboseLogging
        Log-Message "[-] Converting token in progress..." -Verbose:$VerboseLogging
        try {
            $token = ($response.Content | ConvertFrom-Json).access_token
            Log-Message "[+] Token conversion successful" -Verbose:$VerboseLogging
            return $token
        }
        catch {
            Log-Message "[!] Error during token conversion: $_" -Verbose:$VerboseLogging
            return
        }
    }
    catch {
        Log-Message "[!] Error during token retrieval: $_" -Verbose:$VerboseLogging
        return
    }
}

Connect-SharePoint -TenantID "123e4567-e89b-12d3-a456-426614174000" -ClientID "123e4567-e89b-12d3-a456-426614174001" -ClientSecret "SuperSecret123" -LogFile "C:\Logs\Connect-SharePoint.log" -VerboseLogging