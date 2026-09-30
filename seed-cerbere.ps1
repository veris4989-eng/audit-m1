<#
    seed-cerbere.ps1  -  Lab CERBERE (Active Directory & Kerberos)
    ---------------------------------------------------------------------------
    Arme le domaine cerbere.lab pour la chaine AS-REP -> Kerberoast -> DCSync,
    et ACTIVE l'audit necessaire au temps "Detecter" (sans quoi 4768/4769/4662
    n'existent pas).

    A executer SUR le DC, APRES la promotion (Install-ADDSForest), dans une
    console PowerShell ouverte en tant qu'Administrateur du domaine.

    Idempotent : relancable sans casse (cree ce qui manque, passe sur ce qui
    existe deja, ne duplique jamais les ACE dsacls/SACL).
    Les faiblesses sont VOLONTAIRES et documentees dans CORRIGE.md.
    ---------------------------------------------------------------------------
#>

#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

# =========================================================================
# 0. Parametres du domaine
# =========================================================================
$dom        = Get-ADDomain
$DomainDns  = $dom.DNSRoot                # ex: cerbere-a.lab
$NetBIOS    = $dom.NetBIOSName            # ex: CERBEREA
$DomainDN   = $dom.DistinguishedName      # ex: DC=cerbere-a,DC=lab
$OUStaff    = "OU=Personnel,$DomainDN"
$OUSvc      = "OU=Services,$DomainDN"

Write-Host "== Seed CERBERE sur $DomainDns ($DomainDN) ==" -ForegroundColor Cyan

# --- Mots de passe VOLONTAIREMENT faibles (voir CORRIGE.md) --------------
$pSpray = 'Automne2025!'
$pAsrep = 'Summer2016'
$pSvc   = 'Liverpool1'
$pDecoy = 'Rct#9134xZ72kQ'      # comptes figurants : robustes, non exploitables

function SecStr([string]$p){ ConvertTo-SecureString $p -AsPlainText -Force }

function New-LabUser {
    param([string]$Sam,[string]$Given,[string]$Surname,[string]$Pwd,[string]$Path,[string]$Title='')
    $name = "$Given $Surname"
    if (Get-ADUser -Filter "SamAccountName -eq '$Sam'" -ErrorAction SilentlyContinue) {
        Write-Host "  = $Sam (deja present, on passe)" -ForegroundColor DarkGray
    } else {
        New-ADUser -SamAccountName $Sam -Name $name -GivenName $Given -Surname $Surname `
            -UserPrincipalName "$Sam@$DomainDns" -Path $Path -Title $Title `
            -AccountPassword (SecStr $Pwd) -Enabled $true `
            -PasswordNeverExpires $true -CannotChangePassword $true
        Write-Host "  + $Sam" -ForegroundColor Green
    }
}

# =========================================================================
# 1. Unites d'organisation
# =========================================================================
foreach ($ou in @(
    @{Name='Personnel';Path=$DomainDN},
    @{Name='Services'; Path=$DomainDN})) {
    $dn = "OU=$($ou.Name),$($ou.Path)"
    if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue) {
        Write-Host "  = OU $($ou.Name) (deja presente, on passe)" -ForegroundColor DarkGray
    } else {
        New-ADOrganizationalUnit -Name $ou.Name -Path $ou.Path -ProtectedFromAccidentalDeletion $false
        Write-Host "  + OU $($ou.Name)" -ForegroundColor Green
    }
}

# =========================================================================
# 2. Comptes figurants - ROSTER LU DEPUIS users.txt (source unique, editable)
#    Chaque compte du fichier qui n'est ni integre (Administrator/Guest/krbtgt)
#    ni special (p.durand/s.leroy/svc-sql, crees plus bas avec leur role)
#    est cree comme figurant. Editer users.txt = editer le roster.
#    users.txt doit etre A COTE de ce script (meme dossier).
# =========================================================================
$scriptDir  = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$rosterFile = Join-Path $scriptDir 'users.txt'
$builtins   = @('administrator','administrateur','guest','invite','krbtgt')
$special    = @('p.durand','s.leroy','svc-sql')
$niceNames  = @{
  'a.bernard'='Alice|Bernard'; 'm.thomas'='Marc|Thomas'; 'c.petit'='Chloe|Petit';
  'l.robert'='Lucas|Robert';   'e.richard'='Emma|Richard'; 'n.moreau'='Nathan|Moreau';
  'j.simon'='Julie|Simon';     't.laurent'='Thomas|Laurent'; 's.michel'='Sarah|Michel'; 'h.garcia'='Hugo|Garcia'
}
if (Test-Path $rosterFile) {
    $roster = Get-Content $rosterFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^#' }
    Write-Host "  i roster lu depuis users.txt ($($roster.Count) entrees)" -ForegroundColor DarkGray
} else {
    $roster = @($niceNames.Keys)
    Write-Host "  ~ users.txt introuvable a cote du seed -> liste par defaut (10 figurants)" -ForegroundColor DarkYellow
}
foreach ($sam in $roster) {
    $low = $sam.ToLower()
    if ($builtins -contains $low -or $special -contains $low) { continue }   # integres + speciaux geres ailleurs
    if ($niceNames.ContainsKey($low)) {
        $g,$s = $niceNames[$low].Split('|')
    } else {
        $parts = $sam.Split('.')
        $g = $parts[0]; if ($g) { $g = $g.Substring(0,1).ToUpper() + $g.Substring(1) }
        $s = if ($parts.Count -gt 1) { $parts[-1] } else { 'Lab' }
        if ($s) { $s = $s.Substring(0,1).ToUpper() + $s.Substring(1) }
    }
    New-LabUser -Sam $sam -Given $g -Surname $s -Pwd $pDecoy -Path $OUStaff -Title 'Personnel'
}

# =========================================================================
# 3. FAIBLESSE 1 - compte "spray" (motif Saison+Annee+!)
# =========================================================================
New-LabUser -Sam 'p.durand' -Given 'Paul' -Surname 'Durand' -Pwd $pSpray -Path $OUStaff -Title 'Assistant'

# =========================================================================
# 4. FAIBLESSE 2 - AS-REP roasting
#    Compte SANS pre-authentification Kerberos + chiffrement RC4 force
# =========================================================================
New-LabUser -Sam 's.leroy' -Given 'Sophie' -Surname 'Leroy' -Pwd $pAsrep -Path $OUStaff -Title 'Gestionnaire'

$sleroy = Get-ADUser 's.leroy' -Properties DoesNotRequirePreAuth,msDS-SupportedEncryptionTypes
if ($sleroy.DoesNotRequirePreAuth -eq $true -and $sleroy.'msDS-SupportedEncryptionTypes' -eq 4) {
    Write-Host "  = s.leroy deja configure (pre-auth off + RC4), on passe" -ForegroundColor DarkGray
} else {
    Set-ADAccountControl -Identity 's.leroy' -DoesNotRequirePreAuth $true
    Set-ADUser -Identity 's.leroy' -Replace @{'msDS-SupportedEncryptionTypes'=4}   # 4 = RC4_HMAC uniquement
    Write-Host "  ! s.leroy : pre-auth desactivee + RC4 force (AS-REP roastable)" -ForegroundColor Yellow
}

# =========================================================================
# 5. FAIBLESSE 3 - Kerberoasting
#    Compte de service avec SPN + RC4 force + mot de passe faible
# =========================================================================
New-LabUser -Sam 'svc-sql' -Given 'Service' -Surname 'SQL' -Pwd $pSvc -Path $OUSvc -Title 'Compte de service SQL'

$spnCible = "MSSQLSvc/srv-sql.$DomainDns:1433"
$svcsql   = Get-ADUser 'svc-sql' -Properties ServicePrincipalNames,msDS-SupportedEncryptionTypes
if ($svcsql.ServicePrincipalNames -contains $spnCible -and $svcsql.'msDS-SupportedEncryptionTypes' -eq 4) {
    Write-Host "  = svc-sql deja configure (SPN + RC4), on passe" -ForegroundColor DarkGray
} else {
    Set-ADUser -Identity 'svc-sql' -ServicePrincipalNames @{Replace=$spnCible}
    Set-ADUser -Identity 'svc-sql' -Replace @{'msDS-SupportedEncryptionTypes'=4}
    Write-Host "  ! svc-sql : SPN MSSQLSvc + RC4 force (kerberoastable)" -ForegroundColor Yellow
}

# =========================================================================
# 6. FAIBLESSE 4 - chemin vers Domain Admin : DCSync
#    On donne a svc-sql les DEUX droits de replication sur la tete de domaine.
#    On pose l'ACE via System.DirectoryServices + le GUID du droit etendu
#    (et NON via 'dsacls ...:CA;Replicating Directory Changes') : sur un
#    Windows Server EN FRANCAIS, dsacls attend le nom LOCALISE du droit
#    ("Modifications de la replication du repertoire") ; la version anglaise
#    ne matche pas -> droit silencieusement NON accorde -> DCSync qui refuse
#    au TP2. Le GUID est identique quelle que soit la langue. Meme approche
#    (GUID + SID) que la SACL de la section 8.
# =========================================================================
$replGuids = @('1131f6aa-9c07-11d1-f79f-00c04fc2dcd2',   # DS-Replication-Get-Changes
               '1131f6ad-9c07-11d1-f79f-00c04fc2dcd2')   # DS-Replication-Get-Changes-All
$svcSqlSid = (Get-ADUser 'svc-sql').SID
$adDomPath = "AD:\$DomainDN"
$erRightCA = [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight
$allow     = [System.Security.AccessControl.AccessControlType]::Allow

$aclDom = Get-Acl -Path $adDomPath
$replAcesDeja = $aclDom.Access | Where-Object {
    $_.IdentityReference -like "*svc-sql*" -and
    $_.ObjectType -in @([GUID]$replGuids[0], [GUID]$replGuids[1])
}
if ((@($replAcesDeja).Count) -ge 2) {
    Write-Host "  = svc-sql a deja les droits de replication (DCSync), on passe" -ForegroundColor DarkGray
} else {
    foreach ($g in $replGuids) {
        $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                   $svcSqlSid, $erRightCA, $allow, ([GUID]$g))
        $aclDom.AddAccessRule($ace)
    }
    Set-Acl -Path $adDomPath -AclObject $aclDom
    Write-Host "  ! svc-sql : droits de replication accordes via GUID (DCSync possible)" -ForegroundColor Yellow
}

# =========================================================================
# 7. AUDIT - indispensable au temps "Detecter"
#    Sans ces sous-categories, 4768/4769/4662 ne sont jamais journalises.
#    NB: on passe par les GUID (et non les noms) pour eviter l'erreur
#    0x00000057 sur les builds Windows non-anglaises (auditpol attend le
#    nom localise sinon).
# =========================================================================
$subs = @(
    @{Guid='{0CCE9242-69AE-11D9-BED3-505054503030}'; Label='Kerberos Authentication Service'},   # 4768/4771
    @{Guid='{0CCE9240-69AE-11D9-BED3-505054503030}'; Label='Kerberos Service Ticket Operations'}, # 4769
    @{Guid='{0CCE923B-69AE-11D9-BED3-505054503030}'; Label='Directory Service Access'},           # 4662
    @{Guid='{0CCE9215-69AE-11D9-BED3-505054503030}'; Label='Logon'},                              # 4625
    @{Guid='{0CCE9217-69AE-11D9-BED3-505054503030}'; Label='Account Lockout'}
)
foreach ($s in $subs) {
    & auditpol /set /subcategory:"$($s.Guid)" /success:enable /failure:enable | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [!!] auditpol a echoue pour $($s.Label) ($($s.Guid))" -ForegroundColor Red
    }
}
Write-Host "  + Audit avance active (Kerberos, annuaire, logon)" -ForegroundColor Green

# =========================================================================
# 8. SACL sur la tete de domaine - fait apparaitre l'event 4662 au DCSync
#    On audite (Success) l'usage des deux droits de replication par Tout le monde.
# =========================================================================
$adPath   = "AD:\$DomainDN"
$acl      = Get-Acl -Path $adPath -Audit    # -Audit : charge la SACL, sinon 2e passage = doublon
$everyone = New-Object System.Security.Principal.SecurityIdentifier(
                [System.Security.Principal.WellKnownSidType]::WorldSid, $null)
$erRight  = [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight
$success  = [System.Security.AccessControl.AuditFlags]::Success
$noInherit= [System.DirectoryServices.ActiveDirectorySecurityInheritance]::None

$saclDeja = $acl.Audit | Where-Object {
    $_.IdentityReference -eq $everyone.Translate([System.Security.Principal.NTAccount]) -and
    $_.AuditFlags -eq $success -and
    $_.ObjectType -in @([GUID]$replGuids[0], [GUID]$replGuids[1])
}
if ((@($saclDeja).Count) -ge 2) {
    Write-Host "  = SACL replication deja posee, on passe" -ForegroundColor DarkGray
} else {
    foreach ($g in $replGuids) {
        $ace = New-Object System.DirectoryServices.ActiveDirectoryAuditRule(
                   $everyone, $erRight, $success, ([GUID]$g), $noInherit)
        $acl.AddAuditRule($ace)
    }
    Set-Acl -Path $adPath -AclObject $acl
    Write-Host "  + SACL replication posee sur la tete de domaine (event 4662 au DCSync)" -ForegroundColor Green
}

# =========================================================================
# 8b. ACCESSIBILITE RESEAU (lab ferme) - la Kali doit joindre le DC
#     L'attaque fait du SMB (banniere, spray) + RPC (DCSync via impacket) +
#     ICMP (ping du critere d'acceptation). Sur un bridge isole, la carte
#     peut etre classee "Public" -> ces flux entrants sont bloques.
#     On coupe le pare-feu Windows sur ce DC jetable, en reseau ferme.
#     Convenance de LAB, PAS une pratique de production.
# =========================================================================
Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False
Write-Host "  + Pare-feu desactive (lab ferme : SMB 445, RPC, ICMP joignables)" -ForegroundColor Green

# =========================================================================
# 9. Recapitulatif
# =========================================================================
Write-Host ""
Write-Host "== Seed termine ==" -ForegroundColor Cyan
Write-Host "  Domaine        : $DomainDns"
Write-Host "  Comptes cibles : figurants (users.txt) + p.durand + s.leroy + svc-sql"
Write-Host "  Faiblesses     : spray(p.durand) / AS-REP(s.leroy) / Kerberoast(svc-sql) / DCSync(svc-sql)"
Write-Host "  Audit          : Kerberos + annuaire + logon actives, SACL replication posee"
Write-Host "  Reseau         : pare-feu coupe (SMB/RPC/ICMP joignables depuis la Kali)"
Write-Host ""
Write-Host "  Mots de passe plantes (a garder cote FORMATEUR) :" -ForegroundColor DarkYellow
Write-Host "    p.durand = $pSpray   |   s.leroy = $pAsrep   |   svc-sql = $pSvc"
Write-Host ""
Write-Host "  Verifs rapides :" -ForegroundColor DarkGray
Write-Host "    Get-ADUser -Filter * -SearchBase '$OUStaff' | ft SamAccountName"
Write-Host "    Get-ADUser s.leroy -Properties DoesNotRequirePreAuth | fl SamAccountName,DoesNotRequirePreAuth"
Write-Host "    Get-ADUser svc-sql -Properties ServicePrincipalNames | fl SamAccountName,ServicePrincipalNames"
Write-Host "    auditpol /get /subcategory:'{0CCE923B-69AE-11D9-BED3-505054503030}'"

# =========================================================================
# 10. AUTO-VERIFICATION - chaque faiblesse est-elle bien en place ?
# =========================================================================
function Check([string]$label, [bool]$ok) {
    if ($ok) { Write-Host ("  [OK] " + $label) -ForegroundColor Green }
    else     { Write-Host ("  [!!] " + $label + "  <-- A CORRIGER") -ForegroundColor Red }
}
Write-Host ""
Write-Host "== Auto-verification ==" -ForegroundColor Cyan

Check "OU Personnel + Services" ([bool](Get-ADOrganizationalUnit -Filter "Name -eq 'Personnel'") -and [bool](Get-ADOrganizationalUnit -Filter "Name -eq 'Services'"))
Check "p.durand present (spray)" ([bool](Get-ADUser -Filter "SamAccountName -eq 'p.durand'"))
Check "s.leroy sans pre-auth (AS-REP)" ((Get-ADUser s.leroy -Properties DoesNotRequirePreAuth).DoesNotRequirePreAuth -eq $true)
Check "s.leroy chiffrement RC4 (etype=4)" ((Get-ADUser s.leroy -Properties msDS-SupportedEncryptionTypes).'msDS-SupportedEncryptionTypes' -eq 4)
Check "svc-sql SPN MSSQLSvc (Kerberoast)" ([bool]((Get-ADUser svc-sql -Properties ServicePrincipalNames).ServicePrincipalNames -match 'MSSQLSvc'))
Check "svc-sql chiffrement RC4 (etype=4)" ((Get-ADUser svc-sql -Properties msDS-SupportedEncryptionTypes).'msDS-SupportedEncryptionTypes' -eq 4)
$replAces = (Get-Acl "AD:\$DomainDN").Access | Where-Object {
    $_.IdentityReference -like '*svc-sql*' -and
    $_.ObjectType -in @([GUID]$replGuids[0], [GUID]$replGuids[1])
}
Check "svc-sql droits de replication (DCSync)" ((@($replAces).Count) -ge 2)
Check "pare-feu desactive (SMB/ping joignables)" (-not ((Get-NetFirewallProfile).Enabled -contains $true))

Write-Host ""
Write-Host "  Audit (doit indiquer Reussite / Success) :" -ForegroundColor DarkGray
auditpol /get /subcategory:"{0CCE9240-69AE-11D9-BED3-505054503030}"
auditpol /get /subcategory:"{0CCE923B-69AE-11D9-BED3-505054503030}"
Write-Host ""
Write-Host "  Tout en [OK] vert + audit = Reussite  ->  DC pret pour le lab." -ForegroundColor Cyan
