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

function Mask-String {
    param (
        [Parameter(Mandatory=$true)]
        [string]$String
    )

    if ($String.Length -le 4) {
        # Si le mot de passe est très court, ne pas masquer
        return '*' * $String.Length
    }

    $firstPart = $String.Substring(0, 2)
    $lastPart = $String.Substring($String.Length - 2, 2)
    $maskedPart = '*' * ($String.Length - 4)

    return "$firstPart$maskedPart$lastPart"
}
# Masquer une chaîne de caractères avec une longueur supérieure à 4
$maskedString = Mask-String -String "SuperSecretPassword"
Write-Host "Masqué: $maskedString"

# Masquer une chaîne de caractères avec une longueur de 4 ou moins
$shortString = Mask-String -String "1234"
Write-Host "Masqué: $shortString"


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

function Export-SharePointFile {
    param (
        [Parameter(Mandatory=$true, HelpMessage="Nom du site SharePoint contenant le fichier à télécharger.")]
        [Alias("Site")]
        [ValidatePattern("^[a-zA-Z0-9\-]+$")]  # Valide les noms de site SharePoint
        [string]$SiteName,

        [Parameter(Mandatory=$false, HelpMessage="Nom de la librairie du site Sharepoint contenant le fichier à télécharger. Par défaut Documents")]
        [Alias("Library")]        
        [string]$LibraryName="Documents",

        [Parameter(Mandatory=$true, HelpMessage="Nom du fichier à télécharger.")]
        [Alias("File")]        
        [string]$FileName,

        [Parameter(Mandatory=$false, HelpMessage="Chemin complet où le fichier téléchargé sera sauvegardé.")]
        [Alias("Path")]
        [ValidateScript({
            if ($_ -match "^[a-zA-Z]:\\(?:[^\\\/:*?`"<>|]+\\)*[^\\\/:*?`"<>|]+\.[a-zA-Z0-9]+$") {
                $true
            } else {
                throw "Le chemin OutFile doit être un chemin complet valide et se terminer par une extension de fichier."
            }
        })]
        [string]$OutFile,

        [Parameter(Mandatory=$true, HelpMessage="Token Microsoft Graph.")]
        [ValidatePattern("^[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+$")]  # Valide le format JWT
        [string]$Token,

        [Parameter(Mandatory=$true, HelpMessage="Nom du tenant associé à l'identifiant unique.")]
        [Alias("Tenant")]
        [string]$TenantName,

        [Parameter(Mandatory=$false, HelpMessage="Indique si les erreurs doivent être affichées.")]
        [switch]$VerboseLogging,

        [Parameter(Mandatory=$false, HelpMessage="Chemin du fichier de journalisation.")]
        [ValidateScript({Test-Path (Split-Path $_ -Parent)})]  # Valide que le dossier de journalisation existe
        [string]$LogFile
    )

    # Si le paramètre OutFile n'est pas fourni, utiliser le nom du fichier téléchargé
    if (-not $OutFile) {
        $OutFile = Join-Path -Path $env:TEMP -ChildPath ([System.IO.Path]::GetFileName($FileName))
    }

    # Affichage des paramètres
    Log-Message "################# Export-SharePointFile #################" -Verbose:$VerboseLogging
    Log-Message "[-] Tenant:    $TenantName" -Verbose:$VerboseLogging
    Log-Message "[-] Site:      $SiteName" -Verbose:$VerboseLogging
    Log-Message "[-] Library:   $LibraryName" -Verbose:$VerboseLogging
    Log-Message "[-] FileName:  $FileName" -Verbose:$VerboseLogging
    Log-Message "[-] OutFile:   $OutFile" -Verbose:$VerboseLogging
                            
    # Récupération de l'ID du fichier
    try {                
        # URL pour obtenir l'ID du fichier                
        $graphApiUrl = "https://graph.microsoft.com/v1.0/sites/$TenantName.sharepoint.com:/sites/${SiteName}:/lists/$LibraryName/items"                        
        Log-Message "[-] Récupération de l'ID de $FileName en cours..." -Verbose:$VerboseLogging
        Log-Message "[-] Graph API URL: $graphApiUrl" -Verbose:$VerboseLogging        
        $fileID = Invoke-RestMethod -Headers @{Authorization = "Bearer $Token"} -Uri $graphApiUrl -Method Get | Select-Object -ExpandProperty value | Where-Object { $_.webUrl -ilike "*/$FileName" } | Select-Object -ExpandProperty id
        if($fileID -and $null -ne $fileID){        
            Log-Message "[+] Récupération de l'ID de $FileName réussie: $fileID" -Verbose:$VerboseLogging
            Log-Message "[-] Téléchargement de $FileName (ID: $fileID) en cours..." -Verbose:$VerboseLogging
            # Téléchargement du fichier
            try {                          
                $graphApiUrl = "https://graph.microsoft.com/v1.0/sites/$TenantName.sharepoint.com:/sites/${SiteName}:/lists/$LibraryName/items/$fileID/driveItem/content"                           
                Log-Message "[-] Graph API URL: $graphApiUrl" -Verbose:$VerboseLogging
                # Requête pour obtenir le contenu du fichier
                Invoke-RestMethod -Headers @{Authorization = "Bearer $Token"} -Uri $graphApiUrl -Method Get -OutFile $OutFile
                Log-Message "[+] Téléchargement du fichier réussi !" -Verbose:$VerboseLogging
                Log-Message "[+] Fichier téléchargé à l'emplacement suivant: $OutFile" -Verbose:$VerboseLogging
                return 0
            }
            catch {
                Log-Message "[!] Erreur lors du téléchargement du fichier: $_" -Verbose:$VerboseLogging
            }
        }
        else {
            Log-Message "[!] Erreur lors de la récupération de l'ID du fichier: $FileName n'existe pas dans la bibliothèque $LibraryName. Vérifiez les différentes informations et recommencez." -Verbose:$VerboseLogging
        }        
    }
    catch {
        Log-Message "[!] Erreur lors de la récupération de l'ID du fichier: $_" -Verbose:$VerboseLogging
    }
}
Export-SharePointFile -SiteName "MonSite" -LibraryName "Documents" -FileName "monfichier.docx" -OutFile "C:\Chemin\Vers\Le\Fichier\monfichier.docx" -Token "eyJ0eXAiOiJKV1QiLCJhbGciOi..." -TenantName "MonTenant" -LogFile "C:\Logs\Export-SharePointFile.log" -VerboseLogging