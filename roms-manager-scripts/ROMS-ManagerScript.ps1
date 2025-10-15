# Fonction pour supprimer les doublons selon les tags [*] dans le nom
function Invoke-RemoveBracketTagDoublons {
    param(
        [Parameter(Mandatory=$false)]
        [string]$TargetPath,
        [switch]$WhatIf
    )
    if ([string]::IsNullOrEmpty($TargetPath)) { $TargetPath = Get-Location }
    if (-not (Test-Path -Path $TargetPath)) { Write-Error "Le chemin n'existe pas."; return }
    $AllFiles = Get-ChildItem -Path $TargetPath -Recurse -File -ErrorAction SilentlyContinue
    if ($AllFiles.Count -eq 0) { Write-Host "Aucun fichier trouve." -ForegroundColor Yellow; return }
    # Regroupement par nom en ignorant le tag [*] (tous les fichiers similaires sont doublons)
    $groups = @{}
    foreach ($f in $AllFiles) {
        # Amélioration : regex insensible à la casse, gestion des espaces
        $base = $f.BaseName -replace "\s*\[[a-zA-Z0-9!]{1,3}\]", "", "IgnoreCase"
        if ([string]::IsNullOrEmpty($base)) {
            $key = $f.BaseName.ToLower()
        } else {
            $key = $base.ToLower()
        }
        if (-not $groups.ContainsKey($key)) { $groups[$key] = @() }
        $groups[$key] += $f
    }
    $doublons = $groups.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }
    if ($doublons.Count -eq 0) {
        Write-Host "Aucun doublon trouve selon le critere [*]." -ForegroundColor Green
        return
    }
    Write-Host "Doublons identifies :" -ForegroundColor Yellow
    foreach ($d in $doublons) {
        $names = $d.Value | ForEach-Object { $_.Name }
        Write-Host "  - $($names -join ', ')" -ForegroundColor White
    }
    if ($WhatIf) {
        Write-Host "\nMode WhatIf : Aucun fichier ne sera supprime." -ForegroundColor Cyan
        return
    }
    # Priorité de suppression
    $priority = @("!", "h1", "h2", "h3", "h4", "h5", "h6", "c", "c1", "c2", "b", "b1", "b2")
    $deleted = 0
    foreach ($d in $doublons) {
        $files = $d.Value
        $keep = $files | Where-Object { $_.BaseName -notmatch "\[[a-zA-Z0-9!]{1,3}\]" }
        if ($keep.Count -gt 0) {
            $keep = $keep | Select-Object -First 1
        } else {
            foreach ($p in $priority) {
                $regex = "\[$p\]"
                $keep = $files | Where-Object { $_.BaseName -match $regex }
                if ($keep.Count -gt 0) {
                    $keep = $keep | Select-Object -First 1
                    break
                }
            }
        }
        if (-not $keep -or $keep.Count -eq 0) { $keep = $files | Select-Object -First 1 }
        Write-Host "Conserve : $($keep.Name)" -ForegroundColor Cyan
        foreach ($f in $files) {
            if ($f.FullName -eq $keep.FullName) { continue }
            try {
                Remove-Item -Path $f.FullName -Force -ErrorAction Stop
                Write-Host "Supprime : $($f.Name)" -ForegroundColor Red
                $deleted++
            } catch {
                Write-Error "Erreur suppression $($f.Name) : $_"
            }
        }
    }
    Write-Host "\nSuppression terminee. Fichiers supprimes : $deleted" -ForegroundColor Green
}
# Script PowerShell pour zipper les fichiers non-archives dans un repertoire et ses sous-dossiers
# Utilisation : .\Script.ps1 [-Path "C:\VotreRepertoire"] [-WhatIf]
# Si aucun parametre n'est specifie, un menu interactif s'affiche pour choisir les options.
# Attention : Ce script supprime les fichiers originaux apres compression. Testez d'abord avec -WhatIf.
# Optimisations : 
# - Filtrage precoce des fichiers non-archives avec Where-Object pour eviter de traiter les archives inutilement.
# - Parallélisation des operations de compression (requiert PowerShell 7+ pour ForEach-Object -Parallel).
# - Limitation du nombre de threads paralleles a 4 pour eviter la surcharge systeme (ajustable).
# - Collecte des resultats pour les compteurs et logs, evitant les Write-Host chaotiques en parallele.
# - Compatibilite : Si PowerShell < 7, utilisation sequentielle au lieu de parallele.
# Fonctionnalite NFO : Generation de fichiers .nfo dans chaque sous-dossier avec liste des fichiers, en-tete et attributs en lecture seule.
# Nouvelles fonctionnalites : 
# - Option de suppression des fichiers .nfo (recursif).
# - Pour la generation .nfo : choix du niveau de profondeur (1 a *) et emplacement (sous-dossier ou parent).

param(
    [Parameter(Mandatory=$false)]
    [string]$Path,

    [switch]$WhatIf
)

# Liste partagée des extensions exclues (utilisee par plusieurs fonctions)
$Script:ArchiveExtensions = @('.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz', '.cab', '.iso', '.nfo', '.txt', '.bat', '.ps1', '.ct')

# Fonction principale pour zipper les fichiers non-archives
function Invoke-ZipNonArchives {
    param(
        [Parameter(Mandatory=$false)]
        [string]$TargetPath,

        [switch]$Simulate,

        [int]$MaxParallelJobs = 4  # Nombre maximum de threads paralleles (ajustable)
    )

    # Si aucun chemin n'est fourni, utiliser le dossier courant
    if ([string]::IsNullOrEmpty($TargetPath)) {
        $TargetPath = Get-Location
    }

    # Verifier si le chemin existe
    if (-not (Test-Path -Path $TargetPath)) {
        Write-Error "Le chemin n'existe pas."
        return
    }

    # Utiliser la liste partagée des extensions exclues
    $ArchiveExtensions = $Script:ArchiveExtensions

    # Obtenir tous les fichiers recursivement et filtrer des le depart les non-archives
    Write-Host "Scan des fichiers..." -ForegroundColor Yellow
    $AllFiles = Get-ChildItem -Path $TargetPath -Recurse -File -ErrorAction SilentlyContinue
    if ($AllFiles.Count -eq 0) {
        Write-Host "Aucun fichier trouve et ses sous-dossiers." -ForegroundColor Yellow
        return
    }

    # Filtrer les archives et separer les categories
    $NonArchiveFiles = $AllFiles | Where-Object { $ArchiveExtensions -notcontains $_.Extension.ToLower() }
    $ArchiveFiles = $AllFiles | Where-Object { $ArchiveExtensions -contains $_.Extension.ToLower() }

    $IgnoredCount = $ArchiveFiles.Count
    if ($IgnoredCount -gt 0) {
        Write-Host "Fichiers ignores (archives) : $IgnoredCount" -ForegroundColor Cyan
        # Optionnel : Lister les noms si peu nombreux, sinon resumer
        if ($IgnoredCount -le 10) {
            $ArchiveFiles | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Cyan }
        } else {
            Write-Host "  (Trop nombreux pour lister; utilisez Get-ChildItem pour details)" -ForegroundColor Cyan
        }
    }

    $FilesToProcess = $NonArchiveFiles
    $ProcessedCount = 0
    $ErrorCount = 0

    if ($FilesToProcess.Count -eq 0) {
        Write-Host "Aucun fichier non-archive a traiter." -ForegroundColor Yellow
        Write-Host "Traitement termine. Fichiers traites : 0. Fichiers ignores : $IgnoredCount." -ForegroundColor White
        return
    }

    Write-Host "Fichiers a compresser : $($FilesToProcess.Count)" -ForegroundColor Green

    if ($Simulate) {
        # Mode simulation : sequentiel pour simplicite et lisibilite
        Write-Host "`n--- Mode Simulation ---" -ForegroundColor Yellow
        foreach ($File in $FilesToProcess) {
            $ZipName = $File.BaseName + '.zip'
            Write-Host "WhatIf: Compresser '$($File.Name)' vers '$ZipName' et supprimer l'original." -ForegroundColor Yellow
        }
        $ProcessedCount = $FilesToProcess.Count  # Tous "traites" en simulation
    } else {
        # Mode reel : parallele si PowerShell 7+, sinon sequentiel
        $IsPowerShell7Plus = $PSVersionTable.PSVersion.Major -ge 7
        if ($IsPowerShell7Plus) {
            Write-Host "`n--- Mode Reel (Parallele avec $MaxParallelJobs threads max) ---" -ForegroundColor Green

            # Collecter les resultats des operations paralleles
            $Results = $FilesToProcess | ForEach-Object -Parallel {
                $File = $_
                $ArchiveExtensions = $using:ArchiveExtensions  # Passer les variables aux threads
                $ZipName = $File.BaseName + '.zip'
                $ZipPath = Join-Path -Path $File.DirectoryName -ChildPath $ZipName

                try {
                    Compress-Archive -Path $File.FullName -DestinationPath $ZipPath -CompressionLevel Optimal -Force -ErrorAction Stop
                    Remove-Item -Path $File.FullName -Force -ErrorAction Stop
                    return @{
                        Success = $true
                        FileName = $File.Name
                        ZipName = $ZipName
                        Error = $null
                    }
                } catch {
                    return @{
                        Success = $false
                        FileName = $File.Name
                        ZipName = $null
                        Error = $_.Exception.Message
                    }
                }
            } -ThrottleLimit $MaxParallelJobs

            # Traiter les resultats
            foreach ($Result in $Results) {
                if ($Result.Success) {
                    Write-Host "Archive creee : $($Result.ZipName)" -ForegroundColor Green
                    Write-Host "Fichier original supprime : $($Result.FileName)" -ForegroundColor Green
                    $ProcessedCount++
                } else {
                    Write-Error "Erreur lors du traitement de '$($Result.FileName)' : $($Result.Error)"
                    $ErrorCount++
                }
            }
        } else {
            Write-Host "`n--- Mode Reel (Sequentiel - PowerShell < 7) ---" -ForegroundColor Yellow

            # Mode sequentiel pour compatibilite
            foreach ($File in $FilesToProcess) {
                $ZipName = $File.BaseName + '.zip'
                $ZipPath = Join-Path -Path $File.DirectoryName -ChildPath $ZipName

                try {
                    Compress-Archive -Path $File.FullName -DestinationPath $ZipPath -CompressionLevel Optimal -Force -ErrorAction Stop
                    Remove-Item -Path $File.FullName -Force -ErrorAction Stop
                    Write-Host "Archive creee : $ZipName" -ForegroundColor Green
                    Write-Host "Fichier original supprime : $($File.Name)" -ForegroundColor Green
                    $ProcessedCount++
                } catch {
                    Write-Error "Erreur lors du traitement de '$($File.Name)' : $($_.Exception.Message)"
                    $ErrorCount++
                }
            }
        }
    }

    Write-Host "`nTraitement termine. Fichiers traites : $ProcessedCount. Erreurs : $ErrorCount. Fichiers ignores : $IgnoredCount." -ForegroundColor White
}

# Fonction recursive pour lister les fichiers dont l'extension n'est pas dans $Script:ArchiveExtensions
function Invoke-ListNonArchivesRecursive {
    param(
        [Parameter(Mandatory=$false)]
        [string]$TargetPath
    )

    if ([string]::IsNullOrEmpty($TargetPath)) { $TargetPath = Get-Location }
    if (-not (Test-Path -Path $TargetPath)) { Write-Error "Le chemin n'existe pas."; return }

    Write-Host "Listing recursif des fichiers non-archives dans: $TargetPath" -ForegroundColor Cyan

    $AllFiles = Get-ChildItem -Path $TargetPath -Recurse -File -ErrorAction SilentlyContinue
    if ($AllFiles.Count -eq 0) { Write-Host "Aucun fichier trouve." -ForegroundColor Yellow; return }

    $NonArchiveFiles = $AllFiles | Where-Object { $Script:ArchiveExtensions -notcontains $_.Extension.ToLower() }

    if ($NonArchiveFiles.Count -eq 0) {
        Write-Host "Aucun fichier non-archive trouve." -ForegroundColor Yellow
        return
    }

    foreach ($f in $NonArchiveFiles) {
        Write-Host "$($f.FullName)" -ForegroundColor White
    }

    Write-Host "\nTotal: $($NonArchiveFiles.Count) fichiers non-archives." -ForegroundColor Green
}

# Fonction pour deplacer les fichiers contenant (U)/(E) vers un dossier, et (J)/(K) vers un autre
function Invoke-AntiDoublon {
    param(
        [Parameter(Mandatory=$false)]
        [string]$TargetPath,
        [switch]$WhatIf
    )
    if ([string]::IsNullOrEmpty($TargetPath)) { $TargetPath = Get-Location }
    if (-not (Test-Path -Path $TargetPath)) { Write-Error "Le chemin n'existe pas."; return }
    $AllFiles = Get-ChildItem -Path $TargetPath -Recurse -File -ErrorAction SilentlyContinue
    if ($AllFiles.Count -eq 0) { Write-Host "Aucun fichier trouve." -ForegroundColor Yellow; return }
    # Regroupement par nom sans tag (E), (U), (J)
    $groups = @{}
    foreach ($f in $AllFiles) {
        # Enlever le préfixe '0038 - ' (4 chiffres, espace, tiret, espace) s'il existe
        $base = $f.BaseName -replace "^\d{4} - ", ""
        # Enlever le tag (E), (U), (J)
        $base = $base -replace "\s*\([EUJ]\)", ""
        $key = $base.ToLower()
        if (-not $groups.ContainsKey($key)) { $groups[$key] = @() }
        $groups[$key] += $f
    }
    $doublons = $groups.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }
    if ($doublons.Count -eq 0) {
        Write-Host "Aucun doublon trouve selon le critere (E)/(U)/(J)." -ForegroundColor Green
        return
    }
    Write-Host "Doublons identifies :" -ForegroundColor Yellow
    foreach ($d in $doublons) {
        $names = $d.Value | ForEach-Object { $_.Name }
        Write-Host "  - $($names -join ', ')" -ForegroundColor White
    }
    if ($WhatIf) {
        Write-Host "\nMode WhatIf : Aucun fichier ne sera supprime." -ForegroundColor Cyan
        return
    }
    # Suppression des doublons selon priorité : (FR) > (F) > (EU) > (E) > (USA) > (UK) > (U)
    $deleted = 0
    foreach ($d in $doublons) {
        $files = $d.Value
        $keep = $files | Where-Object { $_.BaseName -match "\(FR\)" }
        if ($keep.Count -eq 0) { $keep = $files | Where-Object { $_.BaseName -match "\(F\)" } }
        if ($keep.Count -eq 0) { $keep = $files | Where-Object { $_.BaseName -match "\(EU\)" } }
        if ($keep.Count -eq 0) { $keep = $files | Where-Object { $_.BaseName -match "\(E\)" } }
        if ($keep.Count -eq 0) { $keep = $files | Where-Object { $_.BaseName -match "\(USA\)" } }
        if ($keep.Count -eq 0) { $keep = $files | Where-Object { $_.BaseName -match "\(UK\)" } }
        if ($keep.Count -eq 0) { $keep = $files | Where-Object { $_.BaseName -match "\(U\)" } }
        if ($keep.Count -eq 0) { $keep = $files | Select-Object -First 1 }
        foreach ($f in $files) {
            if ($keep -contains $f) { continue }
            try {
                Remove-Item -Path $f.FullName -Force -ErrorAction Stop
                Write-Host "Supprime : $($f.Name)" -ForegroundColor Red
                $deleted++
            } catch {
                Write-Error "Erreur suppression $($f.Name) : $_"
            }
        }
    }
    Write-Host "\nSuppression terminee. Fichiers supprimes : $deleted" -ForegroundColor Green
}
function Invoke-MoveFilesByTag {
    param(
        [Parameter(Mandatory=$false)]
        [string]$TargetPath,

    [Parameter(Mandatory=$false)]
    [string]$DestU = "U",
    [Parameter(Mandatory=$false)]
    [string]$DestE = "E",
    [Parameter(Mandatory=$false)]
    [string]$DestJ = "J",
    [Parameter(Mandatory=$false)]
    [string]$DestK = "K",
    [Parameter(Mandatory=$false)]
    [string]$DestF = "F",
    [Parameter(Mandatory=$false)]
    [string]$DestI = "I",
    [Parameter(Mandatory=$false)]
    [string]$DestS = "S",
    [Parameter(Mandatory=$false)]
    [string]$DestG = "G",
    [Parameter(Mandatory=$false)]
    [string]$DestHOL = "HOL",

        [switch]$Simulate
    )

    if ([string]::IsNullOrEmpty($TargetPath)) { $TargetPath = Get-Location }
    if (-not (Test-Path -Path $TargetPath)) { Write-Error "Le chemin n'existe pas."; return }

    # Creer dossiers de destination si necessaire
    $DestUFull = Join-Path -Path $TargetPath -ChildPath $DestU
    $DestEFull = Join-Path -Path $TargetPath -ChildPath $DestE
    $DestJFull = Join-Path -Path $TargetPath -ChildPath $DestJ
    $DestKFull = Join-Path -Path $TargetPath -ChildPath $DestK
    $DestFFull = Join-Path -Path $TargetPath -ChildPath $DestF
    $DestIFull = Join-Path -Path $TargetPath -ChildPath $DestI
    $DestSFull = Join-Path -Path $TargetPath -ChildPath $DestS
    $DestGFull = Join-Path -Path $TargetPath -ChildPath $DestG
    $DestHOLFull = Join-Path -Path $TargetPath -ChildPath $DestHOL
    if (-not $Simulate) {
        foreach ($d in @($DestUFull,$DestEFull,$DestJFull,$DestKFull,$DestFFull,$DestIFull,$DestSFull,$DestGFull,$DestHOLFull)) {
            if (-not (Test-Path -Path $d)) { New-Item -Path $d -ItemType Directory | Out-Null }
        }
    }

    Write-Host "Scan des fichiers pour tags -> U,E,J,K,F,I,S,G,HOL" -ForegroundColor Cyan

    $AllFiles = Get-ChildItem -Path $TargetPath -Recurse -File -ErrorAction SilentlyContinue
    if ($AllFiles.Count -eq 0) { Write-Host "Aucun fichier trouve." -ForegroundColor Yellow; return }

    $MovedCount = 0
    $ErrorCount = 0

    foreach ($File in $AllFiles) {
        $name = $File.Name
        if ($name -match "\(\s*([Uu]|US|USA|UK)\s*\)") {
            $dest = $DestUFull
        } elseif ($name -match "\(\s*([Ee]|EU)\s*\)") {
            $dest = $DestEFull
        } elseif ($name -match "\(\s*([Jj]|JP)\s*\)") {
            $dest = $DestJFull
        } elseif ($name -match "\(\s*[Kk]\s*\)") {
            $dest = $DestKFull
        } elseif ($name -match "\(\s*([Ff]|FR)\s*\)") {
            $dest = $DestFFull
        } elseif ($name -match "\(\s*[Ii]\s*\)") {
            $dest = $DestIFull
        } elseif ($name -match "\(\s*[Ss]\s*\)") {
            $dest = $DestSFull
        } elseif ($name -match "\(\s*[Gg]\s*\)") {
            $dest = $DestGFull
        } elseif ($name -match "\(\s*HOL\s*\)") {
            $dest = $DestHOLFull
        } else {
            continue
        }

        $DestPath = Join-Path -Path $dest -ChildPath $name
        if ($Simulate) {
            Write-Host "WhatIf: Move '$($File.FullName)' -> '$DestPath'" -ForegroundColor Yellow
            $MovedCount++
            continue
        }

        try {
            Move-Item -Path $File.FullName -Destination $DestPath -Force -ErrorAction Stop
            Write-Host "Deplace: $($File.Name) -> $dest" -ForegroundColor Green
            $MovedCount++
        } catch {
            Write-Error "Erreur deplacement '$($File.Name)' : $_"
            $ErrorCount++
        }
    }

    Write-Host "\nOperation terminee. Fichiers deplaces: $MovedCount. Erreurs: $ErrorCount." -ForegroundColor White
}

# Fonction pour generer les fichiers .nfo dans chaque sous-dossier
function Invoke-GenerateNfoFiles {
    param(
        [Parameter(Mandatory=$false)]
        [string]$TargetPath,

        [string]$DepthStr,

        [ValidateSet("Subfolder", "Parent")]
        [string]$NfoPlacement = "Subfolder"
    )

    # Si aucun chemin n'est fourni, utiliser le dossier courant
    if ([string]::IsNullOrEmpty($TargetPath)) {
        $TargetPath = Get-Location
    }

    # Verifier si le chemin existe
    if (-not (Test-Path -Path $TargetPath)) {
        Write-Error "Le chemin n'existe pas."
        return
    }

    Write-Host "Scan des sous-dossiers avec profondeur '$DepthStr'..." -ForegroundColor Yellow

    # Obtenir les sous-dossiers selon la profondeur (PowerShell 7+ supporte -Depth, sinon simulation)
    $IsPowerShell7Plus = $PSVersionTable.PSVersion.Major -ge 7
    if ($DepthStr -eq "*") {
        $SubDirectories = Get-ChildItem -Path $TargetPath -Recurse -Directory -ErrorAction SilentlyContinue
    } else {
        try {
            $DepthInt = [int]$DepthStr
            if ($DepthInt -lt 1) {
                Write-Error "La profondeur doit etre au moins 1 ou '*'."
                return
            }
            if ($IsPowerShell7Plus) {
                $SubDirectories = Get-ChildItem -Path $TargetPath -Directory -Depth $DepthInt -ErrorAction SilentlyContinue
            } else {
                # Simulation de -Depth pour PowerShell <7 : utiliser une boucle pour limiter la profondeur
                $SubDirectories = @()
                $queue = @([PSCustomObject]@{Path = $TargetPath; Depth = 0})
                while ($queue.Count -gt 0) {
                    $current = $queue[0]
                    $queue = $queue[1..($queue.Count - 1)]
                    if ($current.Depth -ge $DepthInt) { continue }
                    $items = Get-ChildItem -Path $current.Path -Directory -ErrorAction SilentlyContinue
                    foreach ($item in $items) {
                        $SubDirectories += $item
                        $queue += [PSCustomObject]@{Path = $item.FullName; Depth = $current.Depth + 1}
                    }
                }
            }
        } catch {
            Write-Error "Profondeur invalide. Utilisez un nombre (1+) ou '*'."
            return
        }
    }

    if ($SubDirectories.Count -eq 0) {
        Write-Host "Aucun sous-dossier trouve a cette profondeur." -ForegroundColor Yellow
        return
    }

    $NfoGeneratedCount = 0
    $ErrorCount = 0

    foreach ($Dir in $SubDirectories) {
        try {
            # Obtenir la liste des fichiers dans ce sous-dossier (seulement direct, pas recursif)
            $FilesInDir = Get-ChildItem -Path $Dir.FullName -File -ErrorAction SilentlyContinue
            $FileCount = $FilesInDir.Count

            if ($FileCount -eq 0) {
                Write-Host "Sous-dossier vide ignore : $($Dir.Name)" -ForegroundColor Gray
                continue
            }

            # Calculer la liste unique des extensions presentes (en minuscules, sans doublons, excluant les vides)
            $Extensions = $FilesInDir | ForEach-Object { $_.Extension.ToLower() } | Where-Object { $_ -ne "" } | Sort-Object -Unique
            $ListExt = if ($Extensions.Count -gt 0) { ($Extensions -join ", ") } else { "Aucune extension" }

            # Nom du fichier .nfo : meme nom que le dossier + .nfo
            $NfoName = $Dir.Name + '.nfo'

            # Emplacement selon l'option
            if ($NfoPlacement -eq "Subfolder") {
                $NfoPath = Join-Path -Path $Dir.FullName -ChildPath $NfoName
            } else {
                if ($Dir.Parent) {
                    $NfoPath = Join-Path -Path $Dir.Parent.FullName -ChildPath $NfoName
                } else {
                    Write-Warning "Impossible de placer le .nfo dans le parent pour le repertoire racine : $($Dir.Name)"
                    continue
                }
            }

            # Contenu de l'en-tete inspire de l'exemple (genérique, avec liste des extensions)
            $Header = @"
****************************************************************************
*
* Dossier: $($Dir.Name)
* Nombre de fichiers: $FileCount
* Extensions: $ListExt
*
****************************************************************************
"@

            # Liste des fichiers
            $FileList = $FilesInDir | ForEach-Object { " $($_.Name)" }

            # Contenu complet
            $NfoContent = $Header + "`n`n" + ($FileList -join "`n") + "`n`n****************************************************************************"

            # Ecrire le fichier .nfo
            $NfoContent | Out-File -FilePath $NfoPath -Encoding UTF8 -Force

            # Rendre en lecture seule
            Set-ItemProperty -Path $NfoPath -Name IsReadOnly -Value $true

            Write-Host "Fichier .nfo genere : $NfoName ($NfoPlacement)" -ForegroundColor Green
            $NfoGeneratedCount++
        } catch {
            Write-Error "Erreur lors de la generation du .nfo pour '$($Dir.Name)' : $_"
            $ErrorCount++
        }
    }

    Write-Host "`nGeneration terminee. Fichiers .nfo generes : $NfoGeneratedCount. Erreurs : $ErrorCount." -ForegroundColor White
}

# Nouvelle fonction pour supprimer les fichiers .nfo recursivement
function Invoke-DeleteNfoFiles {
    param(
        [Parameter(Mandatory=$false)]
        [string]$TargetPath
    )

    # Si aucun chemin n'est fourni, utiliser le dossier courant
    if ([string]::IsNullOrEmpty($TargetPath)) {
        $TargetPath = Get-Location
    }

    # Verifier si le chemin existe
    if (-not (Test-Path -Path $TargetPath)) {
        Write-Error "Le chemin n'existe pas."
        return
    }

    Write-Host "Scan des fichiers .nfo..." -ForegroundColor Yellow

    # Obtenir tous les fichiers .nfo recursivement
    $NfoFiles = Get-ChildItem -Path $TargetPath -Filter "*.nfo" -Recurse -File -ErrorAction SilentlyContinue

    if ($NfoFiles.Count -eq 0) {
        Write-Host "Aucun fichier .nfo trouve." -ForegroundColor Yellow
        return
    }

    $DeletedCount = 0
    $ErrorCount = 0

    foreach ($NfoFile in $NfoFiles) {
        try {
            Remove-Item -Path $NfoFile.FullName -Force -ErrorAction Stop
            Write-Host "Fichier .nfo supprime : $($NfoFile.Name)" -ForegroundColor Green
            $DeletedCount++
        } catch {
            Write-Error "Erreur lors de la suppression de '$($NfoFile.Name)' : $_"
            $ErrorCount++
        }
    }

    Write-Host "`nSuppression terminee. Fichiers .nfo supprimes : $DeletedCount. Erreurs : $ErrorCount." -ForegroundColor White
}

# Si des parametres sont fournis, executer directement la fonction (seulement pour zip, pas pour NFO)
if ($Path -or $WhatIf) {
    Invoke-ZipNonArchives -TargetPath $Path -Simulate:$WhatIf
} else {
    # Sinon, afficher un menu interactif
    do {
        Clear-Host
        Write-Host "=== ROMS Manager Script ================================================" -ForegroundColor Green
        Write-Host " "
        Write-Host " 1. Archiver en mode simulation (WhatIf) sur le dossier courant" -ForegroundColor White
        Write-Host " 2. Archiver reellement sur le dossier courant" -ForegroundColor White
        Write-Host " 3. Archiver en mode simulation (WhatIf) sur un chemin specifie" -ForegroundColor White
        Write-Host " 4. Archiver reellement sur un chemin specifie" -ForegroundColor White
        Write-Host " "
        Write-Host " 5. Generer fichiers .nfo pour le dossier courant" -ForegroundColor White
        Write-Host " 6. Generer fichiers .nfo pour un chemin specifie" -ForegroundColor White
        Write-Host " "
        Write-Host " 7. Supprimer fichiers .nfo pour le dossier courant" -ForegroundColor White
        Write-Host " 8. Supprimer fichiers .nfo pour un chemin specifie" -ForegroundColor White
        Write-Host " 9. Antidoublons" -ForegroundColor White
        Write-Host " 10. Lister recursivement les fichiers non-archives" -ForegroundColor White
    Write-Host " 11. Deplacer fichiers par tag (U/E -> dossier, J/K -> dossier)" -ForegroundColor White
    Write-Host " 12. Supprimer doublons par tag [*] (priorité)" -ForegroundColor White
        Write-Host " "
        Write-Host " Q. Quitter" -ForegroundColor Red
        Write-Host " "
        Write-Host "========================================================================" -ForegroundColor Green

        $Choice = Read-Host "Choisissez une option (1-9)"

        switch ($Choice) {
            "1" {
                Write-Host "`nExecution en mode simulation sur le dossier courant..." -ForegroundColor Yellow
                Invoke-ZipNonArchives -Simulate
                Read-Host "Appuyez sur Entree pour continuer"
            }
            "2" {
                $Confirm = Read-Host "Etes-vous sur de vouloir executer reellement ? Cela supprimera les fichiers originaux (O/N)"
                if ($Confirm -eq 'O' -or $Confirm -eq 'o') {
                    Write-Host "`nExecution reelle sur le dossier courant..." -ForegroundColor Green
                    Invoke-ZipNonArchives
                    Read-Host "Appuyez sur Entree pour continuer"
                } else {
                    Write-Host "Operation annulee." -ForegroundColor Yellow
                    Read-Host "Appuyez sur Entree pour continuer"
                }
            }
            "3" {
                $CustomPath = Read-Host "Entrez le chemin du repertoire"
                Write-Host "`nExecution en mode simulation sur un chemin specifie..." -ForegroundColor Yellow
                Invoke-ZipNonArchives -TargetPath $CustomPath -Simulate
                Read-Host "Appuyez sur Entree pour continuer"
            }
            "4" {
                $CustomPath = Read-Host "Entrez le chemin du repertoire"
                $Confirm = Read-Host "Etes-vous sur de vouloir executer reellement sur un chemin specifie ? Cela supprimera les fichiers originaux (O/N)"
                if ($Confirm -eq 'O' -or $Confirm -eq 'o') {
                    Write-Host "`nExecution reelle sur un chemin specifie..." -ForegroundColor Green
                    Invoke-ZipNonArchives -TargetPath $CustomPath
                    Read-Host "Appuyez sur Entree pour continuer"
                } else {
                    Write-Host "Operation annulee." -ForegroundColor Yellow
                    Read-Host "Appuyez sur Entree pour continuer"
                }
            }
            "5" {
                Write-Host "`nGeneration de fichiers .nfo sur le dossier courant..." -ForegroundColor Cyan
                $DepthInput = Read-Host "Niveau de profondeur (1-* pour tous)"
                $PlaceInput = Read-Host "Emplacement du .nfo (Subfolder/Parent)"
                Invoke-GenerateNfoFiles -TargetPath (Get-Location) -DepthStr $DepthInput -NfoPlacement $PlaceInput
                Read-Host "Appuyez sur Entree pour continuer"
            }
            "6" {
                $CustomPath = Read-Host "Entrez le chemin du repertoire"
                Write-Host "`nGeneration de fichiers .nfo sur un chemin specifie..." -ForegroundColor Cyan
                $DepthInput = Read-Host "Niveau de profondeur (1-* pour tous)"
                $PlaceInput = Read-Host "Emplacement du .nfo (Subfolder/Parent)"
                Invoke-GenerateNfoFiles -TargetPath $CustomPath -DepthStr $DepthInput -NfoPlacement $PlaceInput
                Read-Host "Appuyez sur Entree pour continuer"
            }
            "7" {
                $Confirm = Read-Host "Etes-vous sur de vouloir supprimer tous les .nfo dans le dossier courant et sous-dossiers ? (O/N)"
                if ($Confirm -eq 'O' -or $Confirm -eq 'o') {
                    Write-Host "`nSuppression de fichiers .nfo sur le dossier courant..." -ForegroundColor Red
                    Invoke-DeleteNfoFiles
                    Read-Host "Appuyez sur Entree pour continuer"
                } else {
                    Write-Host "Operation annulee." -ForegroundColor Yellow
                    Read-Host "Appuyez sur Entree pour continuer"
                }
            }
            "8" {
                $CustomPath = Read-Host "Entrez le chemin du repertoire"
                $Confirm = Read-Host "Etes-vous sur de vouloir supprimer tous les .nfo dans le chemin specifie et sous-dossiers ? (O/N)"
                if ($Confirm -eq 'O' -or $Confirm -eq 'o') {
                    Write-Host "`nSuppression de fichiers .nfo sur un chemin specifie..." -ForegroundColor Red
                    Invoke-DeleteNfoFiles -TargetPath $CustomPath
                    Read-Host "Appuyez sur Entree pour continuer"
                } else {
                    Write-Host "Operation annulee." -ForegroundColor Yellow
                    Read-Host "Appuyez sur Entree pour continuer"
                }
            }
            "9" {
                $CustomPath = Read-Host "Entrez le chemin du repertoire (ou laissez vide pour courant)"
                $Sim = Read-Host "Mode WhatIf (simulation)? (O/N)"
                if ($Sim -eq 'O' -or $Sim -eq 'o') {
                    Invoke-AntiDoublon -TargetPath $CustomPath -WhatIf
                } else {
                    Invoke-AntiDoublon -TargetPath $CustomPath
                }
                Read-Host "Appuyez sur Entree pour continuer"
            }
            "10" {
                $CustomPath = Read-Host "Entrez le chemin du repertoire (ou laissez vide pour courant)"
                Write-Host "\nListing recursif des fichiers non-archives..." -ForegroundColor Cyan
                Invoke-ListNonArchivesRecursive -TargetPath $CustomPath
                Read-Host "Appuyez sur Entree pour continuer"
            }
            "11" {
                $CustomPath = Read-Host "Entrez le chemin du repertoire (ou laissez vide pour courant)"
                $Sim = Read-Host "Mode simulation? (O/N)"
                if ($Sim -eq 'O' -or $Sim -eq 'o') {
                    Invoke-MoveFilesByTag -TargetPath $CustomPath -Simulate
                } else {
                    $DestU = Read-Host "Nom du dossier destination pour (U) (defaut: U)"
                    if ([string]::IsNullOrEmpty($DestU)) { $DestU = 'U' }
                    $DestE = Read-Host "Nom du dossier destination pour (E) (defaut: E)"
                    if ([string]::IsNullOrEmpty($DestE)) { $DestE = 'E' }
                    $DestJ = Read-Host "Nom du dossier destination pour (J) (defaut: J)"
                    if ([string]::IsNullOrEmpty($DestJ)) { $DestJ = 'J' }
                    $DestK = Read-Host "Nom du dossier destination pour (K) (defaut: K)"
                    if ([string]::IsNullOrEmpty($DestK)) { $DestK = 'K' }
                    Invoke-MoveFilesByTag -TargetPath $CustomPath -DestU $DestU -DestE $DestE -DestJ $DestJ -DestK $DestK
                }
                Read-Host "Appuyez sur Entree pour continuer"
            }
            "12" {
                $CustomPath = Read-Host "Entrez le chemin du repertoire (ou laissez vide pour courant)"
                $Sim = Read-Host "Mode simulation? (O/N)"
                if ($Sim -eq 'O' -or $Sim -eq 'o') {
                    Invoke-RemoveBracketTagDoublons -TargetPath $CustomPath -WhatIf
                } else {
                    Invoke-RemoveBracketTagDoublons -TargetPath $CustomPath
                }
                Read-Host "Appuyez sur Entree pour continuer"
            }
            default {
                Write-Host "Option invalide. Appuyez sur Entree pour continuer." -ForegroundColor Red
                Read-Host
            }
        }
    } while ($Choice -ne "q" -and $Choice -ne "Q")
}