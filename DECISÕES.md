# Decisões técnicas

Este documento registra as principais decisões tomadas durante a construção do laboratório, incluindo os motivos de cada escolha, os problemas encontrados e as soluções adotadas.

## Hypervisor: VMware Workstation Pro

Resolvi utilizar o VMware Workstation Pro porque ele é gratuito para uso pessoal, funciona bem no meu computador Windows com 16 GB de RAM e é uma ferramenta bastante utilizada no mercado. Considerei alternativas como ESXi e Nutanix CE, que oferecem recursos mais próximos de um ambiente corporativo, incluindo VLAN tagging real (802.1Q). Mesmo com a limitação do Workstation em relação a VLANs, optei por usar as redes Host-only para fazer a segmentação necessária no laboratório.

## Segmentação de rede: VMnet2 e VMnet3

Criei duas redes Host-only isoladas para representar diferentes segmentos de uma rede corporativa:

- VMnet2 (`192.168.10.0/24`): rede de servidores, onde ficam o Controlador de Domínio e o servidor Linux.
- VMnet3 (`192.168.20.0/24`): rede destinada aos clientes e à DMZ.

Optei por separar as redes desde o início para que qualquer comunicação entre elas precisasse passar pelo pfSense. Dessa forma, consegui reproduzir no laboratório a ideia de um firewall controlando o tráfego entre diferentes segmentos da rede.

## Domínio: italia.local

Escolhi o nome `italia.local` para o laboratório seguindo a convenção de utilizar `.local` em ambientes internos. Dessa forma, mantive o domínio restrito ao laboratório e evitei utilizar um domínio público real.

## IP estático e DNS local no Controlador de Domínio

Como o Active Directory depende do DNS para localizar os controladores de domínio por meio de registros SRV, configurei o DC01 com um IP fixo (`192.168.10.10`) e defini o próprio servidor como DNS (`127.0.0.1`). Assim, o DC01 passou a atuar simultaneamente como cliente e servidor DNS da rede.

## Nome do servidor definido antes da promoção a Controlador de Domínio

Defini o nome definitivo do servidor (`DC01`) antes de instalar o papel de AD DS, porque o nome do computador passa a fazer parte da identidade dele dentro do Active Directory, incluindo registros DNS, GPOs e outros componentes. Dessa forma, evitei precisar renomear o servidor depois da promoção a Controlador de Domínio.

## Escopo de DHCP: 192.168.10.50–192.168.10.100

Defini o escopo entre `192.168.10.50` e `192.168.10.100`, mantendo o endereço do DC01 (`192.168.10.10`) fora da faixa dinâmica para evitar conflitos. Deixei o gateway em branco porque ele seria definido posteriormente, quando configurasse o pfSense como gateway da rede.

## Problema resolvido: erro de licença durante a instalação do Windows

Durante a instalação do Windows, o VMware criou automaticamente um dispositivo de Floppy (`autoinst.flp`) por causa do recurso "Easy Install". Esse dispositivo acabou interferindo na instalação manual e provocou o erro "Windows cannot find the Microsoft Software License Terms".

A remoção do dispositivo de Floppy resolveu o problema.

## VM Linux (LINUX-SRV01) na mesma rede que o Windows Server

Coloquei o servidor Linux na mesma VMnet2 do Controlador de Domínio por causa da função que cada máquina desempenha, e não pelo sistema operacional utilizado.

Os dois são servidores e fazem parte da mesma camada da arquitetura. O Windows Server concentra serviços como autenticação, DNS e DHCP, enquanto o Linux hospeda a aplicação web.

Defini a VMnet2 como rede de servidores e a VMnet3 como rede de clientes/DMZ. Dessa forma, mantive a separação por função e facilitei o controle do tráfego entre os diferentes segmentos.

## Problema resolvido: sem acesso à internet na rede isolada (VMnet2)

Como configurei a VMnet2 como uma rede Host-only, ela não tinha acesso direto à internet. Durante a instalação dos pacotes no Linux, isso fazia com que comandos como `apt` falhassem ao tentar resolver endereços DNS externos.

Para conseguir concluir a instalação, alterei temporariamente o adaptador da VM para NAT e configurei a rede via DHCP. Depois de instalar os pacotes necessários, voltei para o IP estático e para a VMnet2, mantendo a segmentação planejada.

## Problema resolvido: erro de indentação no netplan

Ao configurar o netplan, cometi um erro de indentação no arquivo YAML, fazendo com que os campos dentro de `nameservers` não fossem interpretados corretamente. Ao aplicar a configuração, o sistema retornava o erro "expected mapping".

Corrigi o problema ajustando a indentação do arquivo. Como YAML depende da estrutura definida pelos espaços, precisei garantir que cada nível estivesse corretamente aninhado e sem utilização de tabs.

## Problema resolvido: página do Nginx não abria no navegador

Depois de testar o Nginx, a rede e o firewall UFW, confirmei que os serviços estavam funcionando. Fiz essa validação com `curl` dentro da própria VM e com `Invoke-WebRequest` no PowerShell do computador host.

Identifiquei então que o problema estava no Edge, que estava convertendo automaticamente o acesso de `http://` para `https://`. Como configurei o Nginx para responder somente na porta 80, a tentativa de HTTPS falhava.

Resolvi o problema acessando explicitamente o endereço com `http://` ou desativando o recurso de atualização automática para HTTPS no Edge.

## pfSense com 3 interfaces de rede (WAN, LAN, OPT1)

Configurei o pfSense com três interfaces porque ele precisava acessar a internet e, ao mesmo tempo, enxergar as duas redes internas para fazer o roteamento e aplicar as regras de firewall:

- WAN: conectada à rede NAT, com acesso à internet via DHCP.
- LAN: conectada à VMnet2, com endereço `192.168.10.1/24`, funcionando como gateway da rede de servidores.
- OPT1: conectada à VMnet3, com endereço `192.168.20.1/24`, funcionando como gateway da rede de clientes/DMZ.

## DHCP desabilitado nas interfaces do pfSense

Decidi não utilizar o pfSense como servidor DHCP porque o DC01 já desempenhava essa função na rede de servidores. Para evitar que dois servidores DHCP distribuíssem configurações diferentes na mesma rede, desabilitei o DHCP do pfSense nas interfaces internas.

## Regras de firewall: negar por padrão, liberar o mínimo necessário

Configurei o firewall seguindo o princípio de negar o tráfego por padrão e liberar somente o que realmente fosse necessário.

Na VMnet3, liberei duas comunicações específicas a partir da rede de clientes:

- DNS, nas portas 53 TCP/UDP, com destino ao DC01.
- HTTP, na porta 80 TCP, com destino ao LINUX-SRV01.

Mantive o restante bloqueado, incluindo o acesso direto da rede de clientes às portas administrativas do Windows Server e o acesso à internet. Com isso, limitei a comunicação entre as redes ao que realmente precisava funcionar.

## Problema resolvido: interface web do pfSense não abria (conflito de IP)

Quando tentei acessar `https://192.168.10.1`, a conexão era recusada, mesmo com o ping funcionando.

Investiguei a configuração e identifiquei um conflito de IP causado pelo adaptador virtual do Windows criado pelo VMware. A opção "Connect a host virtual adapter to this network" já havia atribuído o endereço `.1` à VMnet2 antes da criação do pfSense.

Resolvi o conflito alterando o endereço do adaptador do computador host para `192.168.10.2` e deixando `192.168.10.1` para o pfSense. Também configurei o gateway desse adaptador para `192.168.10.1`.

## Hardening básico aplicado no pfSense

Apliquei algumas medidas básicas de segurança na configuração do pfSense.

Mantive a interface WAN configurada para bloquear redes privadas e blocos "bogon" por padrão. Também não criei regras permitindo conexões iniciadas pela internet em direção às redes internas.

Por fim, alterei a senha padrão do usuário `admin` durante o assistente inicial de configuração.

## Backup via script de snapshot em vez de Veeam

Inicialmente considerei utilizar o Veeam Backup & Replication Community Edition, mas resolvi criar meu próprio script, chamado `snapshot-backup.ps1`, utilizando o `vmrun`, ferramenta de linha de comando do VMware Workstation.

Resolvi utilizar essa abordagem porque queria manter o processo mais simples no laboratório e, ao mesmo tempo, automatizar os backups diretamente com PowerShell.

## Política de backup: RPO 24h, RTO 2h, retenção de 7 snapshots

Defini os parâmetros de backup pensando na realidade deste laboratório, e não em um ambiente de produção funcionando 24 horas por dia.

Escolhi um RPO de 24 horas, aceitando a possibilidade de perder até um dia de trabalho. Para o RTO, defini 2 horas como prazo para restaurar uma VM a partir de um snapshot.

Também defini uma retenção de 7 snapshots por VM, mantendo uma semana de histórico sem ocupar espaço excessivo em disco.

## Script busca o .vmx automaticamente, em vez de usar um caminho fixo

Decidi não exigir no script o caminho completo do arquivo `.vmx` de cada máquina virtual.

Configurei o script para receber a pasta da VM e utilizar `Get-ChildItem` para localizar o arquivo `.vmx`. Com isso, simplifiquei a configuração e reduzi a possibilidade de erros causados por diferenças nos nomes das pastas ou dos arquivos.

## Tarefa agendada testada e depois desabilitada

Criei a tarefa diária no Agendador de Tarefas do Windows e fiz testes manuais para confirmar que a automação funcionava corretamente.

Depois dos testes, deixei a tarefa desabilitada porque as VMs não ficam ligadas continuamente. Assim, evitei execuções desnecessárias em uma máquina que não funciona 24 horas por dia.


