# NettoyerNomFichiers.ps1
# Nettoie récursivement les noms de fichiers selon un modèle défini
# Conserve uniquement la partie entre le premier tiret et la première région (E), (F), (EU)

param (
    [Parameter(Mandatory = $true)]
    [string]$Dossier
)

# Vérifie que le dossier existe
if (-not (Test-Path $Dossier)) {
    Write-Error "Le dossier spécifié n'existe pas : $Dossier"
    exit
}

# Expression régulière :
# ^[^–-]+[-–]\s*   → tout ce qui précède le premier tiret (supprimé)
# (.*?)\s*\((E|F|EU)\) → capture le titre et la région
# Exemple : "0111 - Advance Wars - Dual Strike (E)(FCT).nds"
#            -> $matches[1] = "Advance Wars - Dual Strike"
#               $matches[2] = "E"
$regex = '^[^–-]+[-–]\s*(.*?)\s*\((E|F|EU)\)'

Get-ChildItem -Path $Dossier -File -Recurse | ForEach-Object {
    $ancienNom = $_.Name
    $cheminComplet = $_.FullName
    $extension = $_.Extension

    if ($ancienNom -match $regex) {
        $nouveauNomSansExt = "$($matches[1]) ($($matches[2]))"
        $nouveauNom = "$nouveauNomSansExt$extension"

        # Nouveau chemin complet
        $nouveauChemin = Join-Path -Path $_.DirectoryName -ChildPath $nouveauNom

        # Renommer seulement si le nom est différent
        if ($ancienNom -ne $nouveauNom) {
            try {
                Rename-Item -Path $cheminComplet -NewName $nouveauNom -ErrorAction Stop
                Write-Host "Renommé : '$ancienNom' -> '$nouveauNom'"
            } catch {
                Write-Warning "Impossible de renommer '$ancienNom' : $_"
            }
        }
    }
}
