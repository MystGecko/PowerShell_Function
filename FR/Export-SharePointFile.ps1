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