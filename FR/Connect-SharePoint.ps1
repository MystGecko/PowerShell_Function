function Connect-SharePoint {
    param (
        [Parameter(Mandatory=$true, HelpMessage="Identifiant unique au format UUID.")]
        [Alias("Id")]
        [ValidatePattern("^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$")]  # Valide le format UUID
        [string]$TenantID,

        [Parameter(Mandatory=$true, HelpMessage="Identifiant unique au format UUID de l'application Azure.")]
        [Alias("AppID")]
        [ValidatePattern("^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$")]  # Valide le format UUID
        [string]$ClientID,

        [Parameter(Mandatory=$true, HelpMessage="Secret associé à l'identifiant unique de l'application Azure.")]
        [Alias("Secret")]        
        [string]$ClientSecret,

        [Parameter(Mandatory=$false, HelpMessage="Indique si les erreurs doivent être affichées.")]
        [switch]$VerboseLogging,

        [Parameter(Mandatory=$false, HelpMessage="Chemin du fichier de journalisation.")]
        [ValidateScript({Test-Path (Split-Path $_ -Parent)})]  # Valide que le dossier de journalisation existe
        [string]$LogFile
    )

    # Affichage des paramètres
    Log-Message "################# Connect-SharePoint #################" -Verbose:$VerboseLogging
    Log-Message "[+] TenantID: $TenantID" -Verbose:$VerboseLogging
    Log-Message "[+] ClientID: $ClientID" -Verbose:$VerboseLogging
    $maskedSecret = Mask-String -String $ClientSecret     
    Log-Message "[+] ClientSecret: $maskedSecret" -Verbose:$VerboseLogging

    # Récupération du token
    Log-Message "[-] Récupération du token en cours..." -Verbose:$VerboseLogging
    $graphApiUrl = "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token"
    Log-Message "[-] Graph API URL: $graphApiUrl" -Verbose:$VerboseLogging
    try {
        $response = Invoke-WebRequest -Uri $graphApiUrl -Method Post -Body @{
            grant_type = "client_credentials"
            client_id = $ClientID
            client_secret = $ClientSecret
            scope = 'https://graph.microsoft.com/.default'
        }
        Log-Message "[+] Récupération du token réussie" -Verbose:$VerboseLogging
        Log-Message "[-] Conversion du token en cours..." -Verbose:$VerboseLogging
        try {
            $token = ($response.Content | ConvertFrom-Json).access_token
            Log-Message "[+] Conversion du token réussie" -Verbose:$VerboseLogging
            return $token
        }
        catch {
            Log-Message "[!] Erreur lors de la conversion du token: $_" -Verbose:$VerboseLogging
            return
        }
    }
    catch {
        Log-Message "[!] Erreur lors de la récupération du token: $_" -Verbose:$VerboseLogging
        return
    }
}
Connect-SharePoint -TenantID "123e4567-e89b-12d3-a456-426614174000" -ClientID "123e4567-e89b-12d3-a456-426614174001" -ClientSecret "SuperSecret123" -LogFile "C:\Logs\Connect-SharePoint.log" -VerboseLogging