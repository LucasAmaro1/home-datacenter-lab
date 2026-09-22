# Home Datacenter Lab

Simulação de um datacenter corporativo em casa, usando virtualização, para desenvolver habilidades práticas de infraestrutura: redes, Windows, Linux, firewall e backup.

## Objetivo

- Servidor Windows Server como Controlador de Domínio (AD DS), DNS e DHCP.
- Servidor Linux rodando Nginx.
- Rede interna segmentada, simulando sub-redes corporativas.
- Firewall (pfSense) com regras de acesso entre redes.
- Rotina de backup documentada (RPO/RTO, frequência, retenção).

## Arquitetura

```mermaid
graph TB
    subgraph Internet["Internet (NAT do host)"]
    end

    subgraph pfSense["PFSENSE-FW01 (Firewall / Gateway): 192.168.10.1 / 192.168.20.1"]
    end

    subgraph VMnet2["VMnet2, Rede de Servidores (192.168.10.0/24)"]
        DC01["DC01<br/>Windows Server 2022<br/>AD DS + DNS + DHCP<br/>192.168.10.10"]
        LINUX["LINUX-SRV01<br/>Ubuntu Server + Nginx<br/>192.168.10.20"]
    end

    subgraph VMnet3["VMnet3, Rede de Clientes/DMZ (192.168.20.0/24)"]
        CLIENTS["Clientes / DMZ (a definir)<br/>libera apenas DNS:53 e HTTP:80"]
    end

    Internet --- pfSense
    pfSense --- VMnet2
    pfSense --- VMnet3
    DC01 -.DNS/DHCP.- LINUX
```

## Ferramentas

Hypervisor: VMware Workstation Pro.
Windows: Windows Server 2022 Evaluation.
Linux: Ubuntu Server LTS com Nginx.
Firewall: pfSense CE 2.7.2.
Backup: script PowerShell (vmrun) com snapshot automatizado e retenção.

## Política de backup

RPO de 24 horas, execução diária. RTO estimado em 2 horas, tempo de restauração via snapshot. Retenção dos últimos 7 snapshots automáticos por VM. A rotina roda pelo script [`snapshot-backup.ps1`](./scripts/snapshot-backup.ps1), via `vmrun` (CLI do VMware Workstation), agendado pelo Agendador de Tarefas do Windows.

## Progresso

- [x] Instalação do VMware Workstation Pro
- [x] Criação das redes virtuais segmentadas (VMnet2 e VMnet3)
- [x] Download e instalação do Windows Server 2022 (Desktop Experience)
- [x] Configuração de IP estático e nome do servidor (DC01)
- [x] Promoção a Controlador de Domínio (domínio `italia.local`)
- [x] Instalação e configuração do DNS
- [x] Instalação, autorização e configuração de escopo do DHCP (`192.168.10.50-100`)
- [x] Criação da VM Linux com serviço (Ubuntu Server + Nginx)
- [x] Deploy do pfSense e segmentação de rede (regras de firewall entre VMnet2 e VMnet3)
- [x] Implementação da rotina de backup (RPO/RTO documentado)

## Estrutura do repositório

```
/
├── README.md
├── DECISÕES.md
├── screenshots/   (capturas de tela, na ordem em que as etapas foram feitas)
└── scripts/       (scripts de automação)
```

## Autor

Lucas, estudante de Ciência da Computação e estagiário de TI, em desenvolvimento de habilidades para infraestrutura e cibersegurança.
