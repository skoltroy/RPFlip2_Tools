# AjouterEspaceAvantMajuscule_Corrige.ps1
# Ajoute des espaces avant les majuscules de manière intelligente dans les noms de fichiers (sans toucher à l'extension)
# Exemples :
#   SuperMarioBros.nds -> Super Mario Bros.nds
#   XMLHttpRequest.nds -> XML Http Request.nds
#   ADVANCEWARS.nds -> ADVANCEWARS.nds (ne sera pas transformé en A D V ...)

param (
    [Parameter(Mandatory = $true)]
    [string]$Dossier
)

if (-not (Test-Path $Dossier)) {
    Write-Error "Le dossier spécifié n'existe pas : $Dossier"
    exit 1
}

Get-ChildItem -Path $Dossier -File -Recurse | ForEach-Object {
    $base = $_.BaseName
    $ext  = $_.Extension
    $originalFullName = $_.Name

    # 1) Insère un espace entre une minuscule/chiffre et une majuscule : "aB" -> "a B"
    $step1 = [regex]::Replace($base, '([a-z0-9])([A-Z])', '$1 $2')

    # 2) Sépare une séquence de majuscules suivie d'une majuscule+minuscule : "XMLHttp" -> "XML Http"
    $step2 = [regex]::Replace($step1, '([A-Z])([A-Z][a-z])', '$1 $2')

    # 3) Nettoyage : remplacer plusieurs espaces par un seul et trim
    $nouveauBase = ($step2 -replace '\s{2,}', ' ').Trim()

    $nouveauNom = "$nouveauBase$ext"

    if ($originalFullName -ne $nouveauNom) {
        try {
            Rename-Item -Path $_.FullName -NewName $nouveauNom -ErrorAction Stop
            Write-Host "Renommé : '$originalFullName' -> '$nouveauNom'"
        } catch {
            Write-Warning "Impossible de renommer '$originalFullName' : $_"
        }
    }
}
