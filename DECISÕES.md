# Decisões técnicas

Registro do "porquê" de cada escolha do projeto — útil tanto para revisar o próprio raciocínio quanto para apresentar em entrevistas.

## Hypervisor: VMware Workstation Pro

Escolhido por ser gratuito para uso pessoal, rodar bem em um host Windows com 16GB de RAM, e ser amplamente usado no mercado. Alternativas como ESXi/Nutanix CE oferecem VLAN tagging real (802.1Q), enquanto o Workstation só permite segmentação lógica via redes isoladas (Host-only) — trade-off aceito para um laboratório doméstico.

## Segmentação de rede: VMnet2 e VMnet3

Duas redes Host-only isoladas foram criadas para simular sub-redes corporativas:

- **VMnet2 (192.168.10.0/24)** — rede de servidores (Controlador de Domínio, futuro servidor Linux).
- **VMnet3 (192.168.20.0/24)** — rede de clientes/DMZ.

Isolar as redes desde o início força que qualquer comunicação entre elas passe, futuramente, pelo pfSense — reproduzindo o modelo de firewall entre camadas que existe em redes corporativas reais.

## Domínio: italia.local

Nome escolhido livremente, mas mantendo a convenção de usar extensão `.local` (em vez de `.com` ou outro TLD real) para domínios internos de laboratório, evitando qualquer conflito com domínios públicos existentes na internet.

## IP estático e DNS local no Controlador de Domínio

O Active Directory depende de DNS para localizar controladores de domínio via registros SRV. Por isso o DC01 recebeu IP fixo (`192.168.10.10`) e aponta o próprio DNS para si mesmo (`127.0.0.1`) — ele é ao mesmo tempo cliente e servidor de DNS da rede.

## Nome do servidor definido antes da promoção a Controlador de Domínio

O nome do computador se torna parte permanente da identidade dele dentro do Active Directory (registros DNS, GPOs, replicação). Renomear depois de promovido é significativamente mais arriscado, então o nome definitivo (`DC01`) foi definido antes de instalar o papel de AD DS.

## Escopo de DHCP: 192.168.10.50–192.168.10.100

Faixa reservada dentro da sub-rede de servidores, deixando de fora o próprio IP do DC01 (`.10`) para evitar conflito. O gateway do escopo foi deixado em branco propositalmente, para ser preenchido apenas quando o pfSense estiver configurado como gateway da rede.

## Problema resolvido: erro de licença durante instalação do Windows

Durante a instalação, o VMware gerou automaticamente um dispositivo de Floppy (`autoinst.flp`) como parte do recurso "Easy Install", que conflitou com a instalação manual e causou o erro "Windows cannot find the Microsoft Software License Terms". A remoção do dispositivo de Floppy resolveu o problema — registrado aqui como troubleshooting relevante para o portfólio.

## VM Linux (LINUX-SRV01) na mesma rede que o Windows Server

O servidor Linux foi colocado na mesma VMnet2 do Controlador de Domínio, não por causa do sistema operacional, mas por causa da **função**: ambos são servidores que prestam serviço à rede (autenticação/DNS/DHCP de um lado, aplicação web do outro). A segmentação da VMnet2 (servidores) contra a VMnet3 (clientes/DMZ) é organizada por papel na arquitetura, refletindo o modelo comum em redes corporativas reais.

## Problema resolvido: sem acesso à internet na rede isolada (VMnet2)

Como a VMnet2 é uma rede Host-only, sem saída para a internet por design (essa saída será responsabilidade futura do pfSense), a instalação de pacotes via `apt` falhava com erro de resolução de DNS externo. A solução temporária foi trocar o adaptador de rede da VM para NAT (e a configuração de rede para DHCP) apenas durante a instalação dos pacotes, revertendo para o IP estático e a VMnet2 logo em seguida — mantendo a segmentação de rede pretendida no dia a dia.

## Problema resolvido: erro de indentação no netplan

Uma falha de indentação no YAML de configuração de rede do Ubuntu (netplan) — com os campos filhos de `nameservers` não aninhados corretamente — causou um erro de "expected mapping" ao aplicar a configuração. YAML exige indentação estrita por espaços (nunca tabs), e cada nível de aninhamento precisa ter mais espaços que o nível pai.

## Problema resolvido: página do Nginx não abria no navegador

Após confirmar que o Nginx, a rede e o firewall (UFW) estavam todos funcionando corretamente (validado via `curl` na própria VM e via `Invoke-WebRequest` no PowerShell do host), o problema real era o navegador Edge reescrevendo automaticamente `http://` para `https://`. Como o Nginx só está configurado para responder na porta 80 (HTTP), essa tentativa de HTTPS falhava silenciosamente. A solução foi forçar `http://` na barra de endereço ou desativar o recurso de upgrade automático para HTTPS do Edge.

## pfSense com 3 interfaces de rede (WAN, LAN, OPT1)

Diferente das demais VMs, o pfSense precisa enxergar tanto a internet quanto os dois andares do prédio simultaneamente, para poder rotear e filtrar tráfego entre eles. Por isso recebeu 3 adaptadores de rede: WAN em NAT (saída para a internet, via DHCP), LAN na VMnet2 (`192.168.10.1/24`, gateway da rede de servidores) e OPT1 na VMnet3 (`192.168.20.1/24`, gateway da rede de clientes/DMZ).

## DHCP desabilitado nas interfaces do pfSense

O pfSense poderia distribuir IPs automaticamente, mas o DC01 já cumpre esse papel na rede de servidores. Manter dois servidores DHCP ativos na mesma rede causaria conflito (máquinas recebendo configurações de fontes diferentes e inconsistentes), então o DHCP do pfSense foi mantido desligado em ambas as interfaces internas.

## Regras de firewall: negar por padrão, liberar o mínimo necessário

Por padrão, o pfSense já bloqueia toda saída de uma interface opcional (OPT1/VMnet3) até que regras explícitas sejam criadas — diferente da LAN, que recebe uma regra de liberação automática na instalação. Sobre essa base, foram liberadas apenas duas portas partindo da rede de clientes: DNS (53, TCP/UDP) até o DC01 e HTTP (80, TCP) até o LINUX-SRV01. Todo o restante — incluindo acesso direto a portas administrativas do Windows Server e à internet a partir da rede de clientes — permanece bloqueado, seguindo o princípio de menor privilégio.

## Problema resolvido: interface web do pfSense não abria (conflito de IP)

Ao tentar acessar `https://192.168.10.1`, a conexão era recusada mesmo com ping respondendo. A causa raiz: o recurso "Connect a host virtual adapter to this network" do VMware já havia reivindicado o endereço `.1` da VMnet2 para o adaptador de rede virtual do próprio Windows físico, antes mesmo do pfSense existir — dois dispositivos disputando o mesmo IP na rede. A solução foi mover o adaptador do host físico para `192.168.10.2`, liberando o `.1` para o pfSense, e apontar o gateway desse adaptador para `192.168.10.1`.

## Hardening básico aplicado no pfSense

Confirmado que a interface WAN bloqueia redes privadas e blocos "bogon" (não atribuídos pela IANA) por padrão — proteção contra spoofing de origem. Também confirmado que não existe nenhuma regra de firewall liberando tráfego de entrada vindo da internet (WAN), mantendo o pfSense fechado por padrão para conexões externas. A senha padrão do usuário `admin` da interface web foi substituída durante o assistente de configuração inicial.
