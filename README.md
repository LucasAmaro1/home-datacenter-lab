# Home Datacenter Lab

Simulação de um pequeno datacenter corporativo em casa, usando virtualização, para desenvolver e demonstrar habilidades práticas de infraestrutura (redes, Windows/Linux, virtualização, backup e segurança).

## Objetivo

Montar um ambiente virtualizado com:

- Servidor Windows Server atuando como Controlador de Domínio (AD DS), DNS e DHCP.
- Servidor Linux rodando um serviço (Nginx ou banco de dados).
- Rede interna segmentada, simulando sub-redes corporativas.
- Rotina de backup documentada (RPO/RTO, frequência, retenção).
- Camada de segurança básica com firewall (pfSense) e hardening.

## Arquitetura planejada

```mermaid
graph TB
    subgraph Internet["Internet (NAT do host)"]
    end

    subgraph pfSense["pfSense (Firewall / Gateway)"]
    end

    subgraph VMnet2["VMnet2 - Rede de Servidores (192.168.10.0/24)"]
        DC01["DC01<br/>Windows Server 2022<br/>AD DS + DNS + DHCP<br/>192.168.10.10"]
        LINUX["LINUX-SRV01<br/>Ubuntu Server + Nginx<br/>192.168.10.20"]
    end

    subgraph VMnet3["VMnet3 - Rede de Clientes/DMZ (192.168.20.0/24)"]
        CLIENTS["Clientes / DMZ<br/>(a definir)"]
    end

    Internet --- pfSense
    pfSense --- VMnet2
    pfSense --- VMnet3
    DC01 -.DNS/DHCP.- LINUX
```

## Ferramentas utilizadas

| Camada | Ferramenta |
|---|---|
| Hypervisor | VMware Workstation Pro |
| Sistema Windows | Windows Server 2022 Evaluation |
| Sistema Linux | Ubuntu Server LTS + Nginx |
| Firewall | pfSense |
| Backup | Veeam Community Edition ou scripts de snapshot |

## Progresso

- [x] Instalação do VMware Workstation Pro
- [x] Criação das redes virtuais segmentadas (VMnet2 e VMnet3)
- [x] Download e instalação do Windows Server 2022 (Desktop Experience)
- [x] Configuração de IP estático e nome do servidor (DC01)
- [x] Promoção a Controlador de Domínio (domínio `italia.local`)
- [x] Instalação e configuração do DNS
- [x] Instalação, autorização e configuração de escopo do DHCP (`192.168.10.50-100`)
- [x] Criação da VM Linux com serviço (Ubuntu Server + Nginx)
- [ ] Deploy do pfSense e segmentação de rede
- [ ] Implementação da rotina de backup (RPO/RTO documentado)
- [ ] Hardening básico de segurança

## Estrutura do repositório

```
/
├── README.md
├── DECISÕES.md
├── screenshots/   # capturas de tela numeradas, na ordem em que as etapas foram feitas
└── scripts/       # scripts de automação (ex: backup), conforme forem criados
```

## Autor

Lucas — estudante de Ciência da Computação e estagiário de TI, em desenvolvimento de habilidades para carreira em infraestrutura/cibersegurança.
