<#
.SYNOPSIS
    Rotina de backup via snapshot para as VMs do Home Datacenter Lab.

.DESCRIPTION
    Cria um snapshot com carimbo de data/hora em cada VM listada, usando o
    vmrun (CLI do VMware Workstation), e aplica retenção automatica,
    apagando os snapshots mais antigos alem do numero definido.

    Politica de backup do projeto:
      - RPO: 24 horas (execucao diaria)
      - RTO: 2 horas (tempo estimado para restaurar via snapshot)
      - Retencao: ultimos 7 snapshots por VM

.NOTES
    Autor: Lucas
    Projeto: Home Datacenter Lab
#>

# ----------------------------
# Configuracoes
# ----------------------------

# Caminho do vmrun.exe (ajuste se o VMware Workstation estiver instalado em outro local)
$vmrun = "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"

# Pastas das VMs (o script encontra o .vmx automaticamente dentro de cada uma)
$vmDirs = @(
    @{ Name = "DC01";         Dir = "C:\Users\lucas\OneDrive\Documentos\Virtual Machines\Windows Server 2022" },
    @{ Name = "LINUX-SRV01";  Dir = "C:\Users\lucas\OneDrive\Documentos\Virtual Machines\LINUX-SRV01" },
    @{ Name = "PFSENSE-FW01"; Dir = "C:\Users\lucas\OneDrive\Documentos\Virtual Machines\PFSENSE-FW01" }
)

# Quantos snapshots automaticos manter por VM (retencao)
$retention = 7

# Prefixo usado para identificar snapshots criados por este script
$snapshotPrefix = "Auto-Backup-"

# Pasta de log
$logDir = "C:\HomeLab-Backups\logs"
$logFile = Join-Path $logDir "snapshot-backup.log"

# ----------------------------
# Preparacao
# ----------------------------

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

if (-not (Test-Path $vmrun)) {
    Write-Log "ERRO: vmrun.exe nao encontrado em '$vmrun'. Verifique o caminho de instalacao do VMware Workstation."
    exit 1
}

Write-Log "===== Iniciando rotina de backup ====="

# ----------------------------
# Rotina principal
# ----------------------------

foreach ($vm in $vmDirs) {

    Write-Log "--- Processando VM: $($vm.Name) ---"

    if (-not (Test-Path $vm.Dir)) {
        Write-Log "ERRO: pasta nao encontrada para $($vm.Name): $($vm.Dir)"
        continue
    }

    $vmxFile = Get-ChildItem -Path $vm.Dir -Filter "*.vmx" -File | Select-Object -First 1

    if (-not $vmxFile) {
        Write-Log "ERRO: nenhum arquivo .vmx encontrado em $($vm.Dir)"
        continue
    }

    $vmxPath = $vmxFile.FullName
    Write-Log "Arquivo .vmx localizado: $vmxPath"

    # Cria o snapshot com carimbo de data/hora
    $snapshotName = "$snapshotPrefix" + (Get-Date -Format "yyyy-MM-dd_HHmm")

    try {
        & $vmrun -T ws snapshot "$vmxPath" "$snapshotName" 2>&1 | Out-Null
        Write-Log "Snapshot criado com sucesso: $snapshotName"
    }
    catch {
        Write-Log "ERRO ao criar snapshot para $($vm.Name): $_"
        continue
    }

    # ----------------------------
    # Retencao: apaga snapshots automaticos antigos alem do limite
    # ----------------------------

    try {
        $rawList = & $vmrun -T ws listSnapshots "$vmxPath" 2>&1

        $autoSnapshots = $rawList |
            Where-Object { $_ -like "$snapshotPrefix*" } |
            Sort-Object

        $countExcess = $autoSnapshots.Count - $retention

        if ($countExcess -gt 0) {
            $toDelete = $autoSnapshots | Select-Object -First $countExcess

            foreach ($old in $toDelete) {
                & $vmrun -T ws deleteSnapshot "$vmxPath" "$old" 2>&1 | Out-Null
                Write-Log "Snapshot antigo removido (retencao): $old"
            }
        }
        else {
            Write-Log "Retencao OK: $($autoSnapshots.Count) snapshot(s) automatico(s) presentes (limite: $retention)."
        }
    }
    catch {
        Write-Log "ERRO ao verificar/aplicar retencao para $($vm.Name): $_"
    }
}

Write-Log "===== Rotina de backup finalizada ====="
Write-Log ""
