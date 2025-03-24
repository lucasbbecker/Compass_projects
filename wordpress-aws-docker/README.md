# Implantação do Wordpress em AWS com Docker e Serviços Gerenciados
## Sobre o projeto

Este projeto consiste na instalação e configuração de um ambiente baseado em contêineres para hospedar uma aplicação Wordpress utilizando serviços da AWS. O objetivo é garantir escalabilidade, segurança e boas práticas no provisionamento da infraestrutura.


## Índice

1. [Configuração da VPC (Virtual Private Cloud)](#1-configuração-da-vpc-virtual-private-cloud)  
   - [Criação da VPC](#11-criação-da-vpc)
   - [Criar o NAT Gateway](#12-criar-o-nat-gateway)
   - [Associar o NAT Gateway nas Tabelas de Roteamento](#13-associar-o-nat-gateway-nas-tabelas-de-roteamento)  
2. [Criação dos Security Groups](#2-criação-dos-security-groups)
   - [Configuração do Security Group - LoadBalancer-SecurityGroup](#21-configuração-do-security-group---loadbalancer-securitygroup)
   - [Configuração do Security Group - Server-SecurityGroup](#22-configuração-do-security-group---server-securitygroup)
   - [Configuração do Security Group - Database-SecurityGroup](#23-configuração-do-security-group---database-securitygroup)
   - [Configuração do Security Group - EFS-SecurityGroup](#24-configuração-do-security-group---efs-securitygroup)
3. [Configuração do SSM](#3-configuração-do-ssm)
   - [Criar Função IAM para o SSM](#31-criar-função-iam-para-o-ssm)
4. [Criação do Banco de Dados no RDS](#4-criação-do-banco-de-dados-no-rds)
   - [Criar Banco de Dados RDS](#41-criar-banco-de-dados-rds)
5. [Configuração do EFS](#5-configuração-do-efs)
   - [Criar File System EFS](#51-criar-file-system-efs)
   - [Obter o DNS do EFS](#52-obter-o-dns-do-efs)
6. [Configuração do Template de Instância EC2](#6-configuração-do-template-de-instância-ec2)
   - [Criar Template de Lançamento para Instância EC2](#61-criar-template-de-lançamento-para-instância-ec2)
7. [Configuração do Elastic Load Balancer](#7-configuração-do-elastic-load-balancer)
   - [Criar o Target Group](#71-criar-o-target-group)
   - [Criar o Load Balancer](#72-criar-o-load-balancer)
8. [Configuração do Auto Scaling Group](#8-configuração-do-auto-scaling-group)
   - [Criar e Configurar o Auto Scaling Group](#81-criar-e-configurar-o-auto-scaling-group)
9. [Verificação e Validação](#9-verificação-e-validação)
   - [Verificar o status do Load Balancer](#91-verificar-o-status-do-load-balancer)
   - [Verificar o acesso à aplicação pelo Load Balancer](#92-verificar-o-acesso-à-aplicação-pelo-load-balancer)
   - [Acessar as instâncias EC2 pelo SSM](#93-acessar-as-instâncias-ec2-pelo-ssm)
   

---

## 1. Configuração da VPC (Virtual Private Cloud)

A **VPC (Virtual Private Cloud)** é um ambiente de rede isolado dentro da AWS, permitindo o controle total sobre endereçamento IP, sub-redes, tabelas de rotas e gateways. Isso garante maior **segurança, escalabilidade e flexibilidade** para nossa infraestrutura.

---

## 1.1 Criação da VPC

A VPC é a base da nossa infraestrutura, pois define o escopo da rede onde os recursos da AWS serão implantados.

1. Acesse o **Console de Gerenciamento da AWS**.
2. No painel de navegação à esquerda, clique em **VPC**.
3. Clique na opção **Your VPCs** e depois em **Create VPC**.
4. Selecione a opção **VPC and more**.
5. Preencha as seguintes configurações:
   - **Name tag:** `wp-docker` (Nome da VPC para facilitar a identificação).
   - **IPv4 CIDR block:** `10.0.0.0/16` (Define o intervalo de endereços IP da rede, permitindo até 65.536 endereços).
   - **Número de zonas disponíveis:** `2` (Cria a VPC em duas zonas de disponibilidade para alta disponibilidade).
   - **Número de sub-redes públicas:** `2` (Duas sub-redes acessíveis publicamente).
   - **Número de sub-redes privadas:** `2` (Duas sub-redes isoladas para maior segurança).
   - **NAT Gateways:** `None` (O NAT Gateway será criado manualmente no próximo passo).
6. Clique em **Create VPC**.

---

## 1.2 Criar o NAT Gateway

O **NAT Gateway (Network Address Translation)** permite que recursos em **sub-redes privadas** possam acessar a internet de forma segura, sem ficarem expostos diretamente.

1. No painel de navegação à esquerda, clique em **NAT Gateways**.
2. Clique no botão **Create NAT Gateway**.
3. Preencha as seguintes configurações:
   - **Nome:** `wordpress-natgateway` (Nome para identificação).
   - **Sub-rede pública:** Selecione **uma das sub-redes públicas criadas pela VPC** (exemplo: `sub-rede-publica-1`).
   - **Elastic IP:** Clique em **Allocate Elastic IP** para gerar um IP elástico e associá-lo ao NAT Gateway.
4. Clique em **Create NAT Gateway**.
5. Aguarde até que o **estado** do NAT Gateway fique como **Available** antes de prosseguir.

---

## 1.3 Associar o NAT Gateway nas Tabelas de Roteamento

Agora precisamos **atualizar as tabelas de roteamento** para que as sub-redes privadas utilizem o NAT Gateway para acessar a internet.

1. No painel de navegação à esquerda, clique em **Route Tables**.
2. Identifique as **duas tabelas de roteamento** associadas às sub-redes privadas criadas pela VPC.
   - **Tabela de roteamento para a sub-rede privada 1**.
   - **Tabela de roteamento para a sub-rede privada 2**.
3. Para cada tabela de roteamento:
   - Clique no **ID da tabela** e vá para **Edit routes**.
   - Adicione a seguinte rota:
     - **Destination:** `0.0.0.0/0` (Permite tráfego para qualquer destino).
     - **Target:** Selecione **NAT Gateway** e escolha o **ID do NAT Gateway criado** (`wp-natgateway`).
   - Clique em **Save routes** para salvar as alterações.

---

### 1.4 Concluir a Configuração

Agora que a **VPC** está configurada corretamente, temos:
- **Sub-redes públicas e privadas** estruturadas.
- **NAT Gateway** funcional para permitir acesso à internet a partir das sub-redes privadas.
- **Rotas configuradas** para garantir a conectividade entre os recursos.

Com essa configuração concluída, podemos avançar para a **criação da instância EC2, RDS e EFS**, garantindo um ambiente robusto e seguro.

---

## 2. Criação dos Security Groups

## 2.1 Configuração do Security Group - LoadBalancer-SecurityGroup

### Passo a Passo:
1. Acesse o serviço EC2 no AWS.
2. Clique em **Security Groups** no menu lateral.
3. Clique em **Create Security Group** para criar um novo SG.
4. Preencha as configurações:
   - **Nome:** LoadBalancer-SecurityGroup
   - **VPC:** Selecione a VPC criada anteriormente (por exemplo, `wp-docker`).
5. Defina as regras de entrada (Inbound Rules):
   - **HTTP (Port 80):** Permite tráfego de qualquer origem (0.0.0.0/0) para o seu balanceador de carga.
   - **HTTPS (Port 443):** Permite tráfego de qualquer origem (0.0.0.0/0) para o seu balanceador de carga.
6. Defina as regras de saída (Outbound Rules):
   - **All traffic:** Permite tráfego de saída para Server-SecurityGroup destino (0.0.0.0/0).
7. Clique em **Create**.

### Por que usar este SG?
Este Security Group será responsável por gerenciar o tráfego que chega ao seu **Application Load Balancer** (ALB). O ALB vai direcionar o tráfego HTTP e HTTPS para as instâncias da sua aplicação. As regras de saída garantem que o ALB possa se comunicar livremente com outros serviços.

---

## 2.2 Configuração do Security Group - Server-SecurityGroup

### Passo a Passo:
1. Clique em **Create Security Group** novamente.
2. Preencha as configurações:
   - **Nome:** Server-SecurityGroup
   - **VPC:** Selecione a mesma VPC utilizada anteriormente (`wp-docker`).
3. Defina as regras de entrada (Inbound Rules):
   - **HTTP (Port 80):** Permite tráfego proveniente do SG `LoadBalancer-SecurityGroup` (Custom).
   - **HTTPS (Port 443):** Permite tráfego proveniente do SG `LoadBalancer-SecurityGroup` (Custom).
4. Defina as regras de saída (Outbound Rules):
   - **All traffic:** Permite tráfego de saída para qualquer destino (0.0.0.0/0).
5. Clique em **Create**.

### Por que usar este SG?
Este SG é responsável pelas instâncias de **Application Server** que vão receber tráfego do **Application Load Balancer** (ALB). A configuração das regras de entrada restringe o tráfego para permitir apenas que o ALB envie requisições HTTP e HTTPS para as instâncias do servidor. Isso aumenta a segurança, já que o tráfego de outros locais é bloqueado.

---

## 2.3 Configuração do Security Group - Database-SecurityGroup

### Passo a Passo:
1. Clique em **Create Security Group**.
2. Preencha as configurações:
   - **Nome:** Database-SecurityGroup
   - **VPC:** Selecione a mesma VPC (`wp-docker`).
3. Defina as regras de entrada (Inbound Rules):
   - **MySQL/Aurora (Port 3306):** Permite tráfego proveniente do SG `Server-SecurityGroup` (Custom), garantindo que apenas as instâncias de aplicação possam acessar o banco de dados.
4. Defina as regras de saída (Outbound Rules):
   - **MySQL/Aurora (Port 3306):** Permite tráfego de saída para qualquer destino (0.0.0.0/0).
5. Clique em **Create**.

### Por que usar este SG?
Este SG vai controlar o acesso ao seu banco de dados. O tráfego para o banco de dados (porta 3306) é limitado às instâncias de aplicação que estão associadas ao SG `Server-SecurityGroup`. Dessa forma, só as instâncias autorizadas podem acessar o banco, o que aumenta a segurança do sistema.

---

## 2.4 Configuração do Security Group - EFS-SecurityGroup

### Passo a Passo:
1. Clique em **Create Security Group**.
2. Preencha as configurações:
   - **Nome:** EFS-SecurityGroup
   - **VPC:** Selecione a mesma VPC (`wp-docker`).
3. Defina as regras de entrada (Inbound Rules):
   - **NFS (Port 2049):** Permite tráfego proveniente do SG `Server-SecurityGroup` (Custom), garantindo que apenas as instâncias de aplicação possam acessar o EFS.
4. Defina as regras de saída (Outbound Rules):
   - **All traffic:** Permite tráfego de saída para qualquer destino (0.0.0.0/0).
5. Clique em **Create**.

### Por que usar este SG?
O **EFS (Elastic File System)** é um serviço de armazenamento compartilhado que precisa ser acessado pelas instâncias de aplicação. Este SG limita o acesso ao EFS às instâncias que estão associadas ao `Server-SecurityGroup`, prevenindo que outras instâncias acessem o sistema de arquivos compartilhado.

---

## Resumo

Agora, com todos os Security Groups configurados, seu ambiente está pronto para garantir uma comunicação segura entre o **Load Balancer**, **Application Servers**, **Database** e **EFS**. Cada SG tem a função de proteger e limitar o tráfego, permitindo apenas o necessário para o funcionamento adequado da aplicação.

### SGs Criados:
- **LoadBalancer-SecurityGroup:** Controla o tráfego para o Load Balancer (HTTP/HTTPS).
- **Server-SecurityGroup:** Gerencia o tráfego para os servidores de aplicação (HTTP/HTTPS de ALB).
- **Database-SecurityGroup:** Permite o tráfego entre o servidor de aplicação e o banco de dados.
- **EFS-SecurityGroup:** Permite que os servidores de aplicação acessem o sistema de arquivos compartilhado (EFS).

---

## 3. Configuração do SSM

## 3.1 Criar Função IAM para o SSM
Siga as etapas abaixo para criar uma função IAM necessária para integrar suas instâncias EC2 ao AWS Systems Manager.

#### Passo a Passo:
1. **Acesse o IAM no Console de Gerenciamento da AWS.**
   - No painel de navegação à esquerda, clique em **Roles** (Funções).
2. **Crie uma nova role.**
   - Clique em **Create role** para iniciar a criação de uma função.
3. **Selecione o tipo de entidade confiável.**
   - Escolha **AWS service** como o tipo de entidade confiável.
4. **Escolha o serviço que usará a role.**
   - Selecione **EC2** na lista de serviços disponíveis, pois queremos que as instâncias EC2 usem esta função.
5. **Defina as permissões necessárias.**
   - Na lista de permissões, selecione **Amazon EC2 Role for SSM**. Essa permissão garante que a instância EC2 tenha acesso ao Systems Manager para realizar operações de gerenciamento.
6. **Adicionar tags (opcional).**
   - Clique em **Next: Tags**. Você pode adicionar tags à função, mas essa etapa é opcional.
7. **Revisão da função.**
   - Clique em **Next: Review** para revisar as configurações da função.
8. **Nome da função.**
   - Dê um nome à função, por exemplo, **EC2-SSM-Role**.
9. **Criar a função.**
   - Clique em **Create role** para concluir a criação da função.

### Por que usar essa função IAM?
A função **EC2-SSM-Role** é essencial para permitir que as instâncias EC2 se comuniquem com o AWS Systems Manager. Sem essa função, as instâncias não poderão ser gerenciadas ou automatizadas via SSM, o que pode dificultar a manutenção e a execução de tarefas administrativas.

---

## Resumo
Neste passo, você criou a função IAM **EC2-SSM-Role**, que permite a integração das instâncias EC2 com o **AWS Systems Manager**. Esse é um passo crucial para permitir o gerenciamento remoto das instâncias, facilitando a manutenção e a automação de tarefas.

---

## 4. Criação do Banco de Dados no RDS

## 4.1 Criar Banco de Dados RDS
Siga as etapas abaixo para criar e configurar um banco de dados MySQL no **Amazon RDS**, pronto para ser utilizado pela sua aplicação.

#### Passo a Passo:
1. **Acesse o RDS no Console de Gerenciamento da AWS.**
   - No painel de navegação à esquerda, clique em **Databases** e depois em **Create database** para iniciar a criação do banco de dados.
2. **Escolha a opção Standard Create.**
   - Para ter mais controle sobre as configurações, selecione **Standard Create**.
3. **Selecione MySQL como o banco de dados.**
   - Escolha **MySQL** na lista de motores de banco de dados.
4. **Escolha a versão do MySQL.**
   - Selecione **MySQL 8.4.3** (compatível com o WordPress).
5. **Selecione o template Free tier.**
   - Como estamos utilizando o nível gratuito, selecione o template **Free tier**.
6. **Preencha as configurações do banco de dados:**
   - **DB instance identifier:** Escolha um nome para o banco de dados (por exemplo, `wordpressdb`).
   - **Master username:** Escolha um nome de usuário para o banco de dados (ex: `admin`).
   - **Master password:** Clique em **Generate password** para gerar uma senha automaticamente ou insira uma senha manualmente.
7. **Configurações da instância:**
   - **DB instance class:** Selecione a instância **db.t3.micro** (apta para o nível gratuito).
   - **Storage type:** Selecione **SSD gp3** (mais moderno e mais barato).
   - **Allocated storage:** Defina para **20 GB**, o suficiente para testes e pequenas aplicações.
   - **Enable autoscaling:** Defina um limite de **100 GB** para escalabilidade automática do armazenamento.
8. **Configurações de conectividade:**
   - **VPC:** Selecione a VPC criada anteriormente (`wp-docker`).
   - **Subnet group:** Selecione a **subnetdb-group** criada para o banco de dados.
   - **Public access:** Defina como **No** (não permitir acesso público ao banco de dados).
   - **VPC security group:** Selecione **Database-SecurityGroup** para associar o banco de dados ao Security Group apropriado.
9. **Configurações adicionais:**
   - **DB name:** Insira o nome para o banco de dados, como `wordpressdb`.
   - **Backup:** Desmarque a opção **Enable backups** se não precisar de backups automáticos (para simplificação ou conforme requisitos específicos).
10. **Criar banco de dados:**
    - Clique em **Create database** e aguarde o processo de criação.

### Por que escolher essas configurações?
- **Versão MySQL 8.4.3:** Escolher uma versão compatível com o WordPress é essencial para garantir que a aplicação funcione corretamente.
- **db.t3.micro:** A instância **t3.micro** é ideal para o nível gratuito, oferecendo o equilíbrio entre desempenho e custo.
- **SSD gp3:** O tipo de armazenamento SSD gp3 é moderno e proporciona uma boa performance com um custo reduzido.
- **Public access: No:** Configurar o banco de dados sem acesso público aumenta a segurança da aplicação, permitindo apenas conexões internas via VPC.
- **Desabilitar backups:** Em alguns casos, os backups automáticos podem ser desnecessários, ou você pode gerenciar backups manualmente conforme suas necessidades.

---

## Resumo
Neste passo, você configurou o banco de dados **MySQL 8.4.3** no **Amazon RDS**, com configurações otimizadas para rodar uma aplicação WordPress. As configurações de instância, segurança e conectividade foram ajustadas para garantir um bom desempenho e segurança para a aplicação.


---

## 5. Configuração do EFS

Neste passo, vamos configurar um **Amazon EFS** (Elastic File System) para compartilhar um sistema de arquivos entre várias instâncias EC2. O EFS será configurado de forma segura, garantindo que ele esteja acessível apenas pelas instâncias EC2 dentro de uma VPC privada. Essa configuração é fundamental para armazenar dados persistentes que podem ser acessados por múltiplas instâncias EC2 de forma simples e eficiente.
 

## 5.1 Criar File System EFS
Para começar a configuração do EFS, siga os passos abaixo:

#### Passo a Passo:
1. **Acesse o EFS no Console de Gerenciamento da AWS.**
   - No painel de navegação à esquerda, clique em **EFS** e depois em **Create file system** para iniciar o processo de criação.
2. **Selecione a opção Customize.**
   - A opção **Customize** permite que você personalize as configurações do sistema de arquivos conforme suas necessidades.
3. **Preencha as configurações do sistema de arquivos:**
   - **Name:** Insira um nome descritivo para o sistema de arquivos, como `wordpress-efs`.
   - **Storage class:** Deixe a opção **Regional**, que é adequada para a maioria dos casos, pois os dados são replicados em várias zonas de disponibilidade na região.
   - **Backup:** Desmarque a opção **Enable backups** para desabilitar o backup automático (você pode configurar backups manualmente, se necessário).
4. **Configurações de Rede:**
   - **VPC:** Selecione a **VPC** que você criou anteriormente (`wp-docker`).
   - **Mount targets:**
     - **Availability Zones:** Selecione a **subnet privada** de cada zona de disponibilidade para garantir que o EFS esteja disponível apenas na sub-rede privada, aumentando a segurança.
     - **Security groups:** Remova o **grupo de segurança padrão** e insira o **grupo de segurança SG-EFS** que você criou previamente, garantindo que somente as instâncias EC2 autorizadas possam acessar o EFS.
5. **Clique em Create para criar o EFS.**
   - Após preencher todas as configurações, clique em **Create** para finalizar a criação do sistema de arquivos.

### Por que escolher essas configurações?
- **Storage class: Regional**: A opção **Regional** oferece replicação automática entre várias zonas de disponibilidade, o que melhora a resiliência do sistema de arquivos.
- **Desabilitar backups automáticos:** Desmarcar **Enable backups** pode ser útil caso você tenha um mecanismo de backup diferente ou não precise de backups automáticos para dados temporários.
- **Subnet privada em Availability Zones:** Ao garantir que o EFS esteja disponível apenas em sub-redes privadas, você aumenta a segurança, evitando exposição pública.
- **Security group SG-EFS:** Usar um grupo de segurança dedicado ao EFS garante que apenas instâncias EC2 autorizadas possam acessar os dados armazenados, reforçando a segurança.

---

## 5.2 Obter o DNS do EFS
Após a criação do EFS, é importante obter o nome de domínio (DNS) para que as instâncias EC2 possam montá-lo corretamente.

#### Passo a Passo:
1. **Acesse o EFS no Console de Gerenciamento da AWS.**
   - Após a criação, clique no **ID do sistema de arquivos** para acessar os detalhes do EFS.
2. **Copie o DNS name do EFS.**
   - Na página de detalhes do EFS, copie o **DNS name** do sistema de arquivos. Esse DNS será utilizado para montar o EFS nas instâncias EC2.

---

## Resumo
Neste guia, configuramos o **Amazon EFS** para ser utilizado com instâncias EC2 de maneira segura e eficiente. As configurações personalizadas garantiram que o sistema de arquivos estivesse disponível apenas em sub-redes privadas da VPC, com o acesso controlado por meio de um grupo de segurança dedicado. Além disso, obtivemos o **DNS name** do EFS para que ele possa ser montado nas instâncias EC2 posteriormente.

---

## 6. Configuração do Template de Instância EC2

## 6.1 Criar Template de Lançamento para Instância EC2
Para criar um **template de lançamento** para sua instância EC2, siga os passos abaixo:

#### Passo a Passo:
1. **Acesse o Console de EC2 da AWS.**
   - Navegue até **EC2** no Console de Gerenciamento da AWS e clique em **Launch Templates** no menu à esquerda.
2. **Clique em "Create launch template".**
   - No painel à direita, clique em **Create launch template** para iniciar a criação de um novo template de lançamento.
3. **Preencha as configurações conforme abaixo:**
   - **Template name:** Insira o nome do template, como `wordpress-temp`.
   - **Template version:** Defina como **v1** (versão inicial).
   - **Auto Scaling guidance:** Deixe como **OK**, já que esta opção será configurada mais tarde com o Auto Scaling Group.
4. **Selecione a AMI (Imagem da Instância):**
   - Escolha **Amazon Linux 2** (ou a versão do Amazon Linux que você deseja usar).
5. **Escolha o tipo de instância:**
   - Selecione o tipo **t2.micro**, que é adequado para o nível gratuito.
6. **Configurações de rede:**
   - **VPC:** Selecione a **VPC** criada anteriormente (wp-docker).
   - **Network settings:** Marque a opção **Do not include in launch template**, pois a configuração de rede será definida no Auto Scaling Group posteriormente.
7. **Seleção de Security Group:**
   - **Security Group:** Selecione o grupo de segurança criado para o servidor de aplicação, `Server-SecurityGroup`.
8. **Detalhes avançados:**
   - **IAM Instance Profile:** Selecione o perfil IAM da instância, como **EC2-SSM-Role**, configurado anteriormente para permitir o uso do Systems Manager.
   - **User Data:** Insira o script necessário para instalar o Docker, Docker Compose, e configurar os contêineres para o WordPress e MySQL utilizando o Docker Compose.

#### Exemplo de Script User Data:

```bash
#!/bin/bash
yum update -y
amazon-linux-extras install docker -y
yum install amazon-efs-utils -y
systemctl start docker.service
systemctl enable docker.service
until curl -fL -o /usr/local/bin/docker-compose \
  "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64"; do
  sleep 5
done
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
EFS_ID=$(aws ssm get-parameter --name efs-id --with-decryption --region=us-east-1 --query "Parameter.Value" --output=text)
export EFS_ID
DB_HOST=$(aws ssm get-parameter --name db-host --with-decryption --region=us-east-1 --query "Parameter.Value" --output=text)
export DB_HOST
DB_NAME=$(aws ssm get-parameter --name db-name --with-decryption --region=us-east-1 --query "Parameter.Value" --output=text)
export DB_NAME
DB_USER=$(aws ssm get-parameter --name db-user --with-decryption --region=us-east-1 --query "Parameter.Value" --output=text)
export DB_USER
DB_PASSWORD=$(aws ssm get-parameter --name db-password --with-decryption --region=us-east-1 --query "Parameter.Value" --output=text)
export DB_PASSWORD
mkdir -p /mnt/efs/wordpress
mount -t efs -o tls $EFS_ID:/ /mnt/efs/wordpress
grep -qxF "$EFS_ID:/ /mnt/efs/wordpress efs _netdev,tls,noresvport 0 0" /etc/fstab || echo "$EFS_ID:/ /mnt/efs/wordpress efs _netdev,tls,noresvport 0 0" | tee -a /etc/fstab > /dev/null
echo "services:
  wordpress:
    image: wordpress:latest
    container_name: wordpress
    restart: always
    ports:
      - '80:80'
    environment:
      WORDPRESS_DB_HOST: "\$DB_HOST"
      WORDPRESS_DB_USER: "\$DB_USER"
      WORDPRESS_DB_PASSWORD: "\$DB_PASSWORD"
      WORDPRESS_DB_NAME: "\$DB_NAME"
    volumes:
      - /mnt/efs/wordpress:/var/www/html" >> /home/ec2-user/docker-compose.yml
docker-compose -f /home/ec2-user/docker-compose.yml up

```

---

## Resumo
Nesse passo, configuramos um **template de lançamento** para instâncias EC2, com as configurações necessárias para rodar uma aplicação WordPress conectada ao banco de dados RDS e com suporte a armazenamento persistente via **EFS**. Utilizamos o **Docker** e o **Docker Compose** para facilitar a criação e gestão dos contêineres, garantindo uma solução escalável e eficiente para o WordPress.

Este passo a passo mantém a clareza e a organização, explicando cada uma das etapas e incluindo o script necessário para configurar as instâncias EC2 para rodar o WordPress com Docker.

---

## 7. Configuração do Elastic Load Balancer

### 7.1 Criar o Target Group

1. **Vá para o EC2 no Console de Gerenciamento da AWS.**
   - Acesse o painel do EC2 no console para gerenciar as instâncias e os recursos de rede da AWS.

2. **No menu à esquerda, em Target Groups, clique em Create target group.**
   - O Target Group é usado para agrupar as instâncias que receberão o tráfego do Load Balancer. Crie um novo grupo de destino para suas instâncias EC2.

3. **Preencha os campos da seguinte forma:**
   - **Target group name**: `wordpress-tg`
     - O nome do grupo de destino. Use um nome identificável, como "wordpress-tg" para este caso.
   - **Target type**: `Instances`
     - O tipo de alvo será "Instâncias" porque o Load Balancer irá distribuir o tráfego entre as instâncias EC2.
   - **Protocol**: `HTTP`
     - O protocolo será HTTP, já que estamos lidando com tráfego web.
   - **Port**: `80`
     - A porta que o Load Balancer usará para se comunicar com as instâncias. Como estamos utilizando HTTP, a porta é a 80.
   - **VPC**: Selecione a VPC que você criou anteriormente
     - A VPC selecionada será a rede onde as instâncias e o Load Balancer estarão localizados, garantindo comunicação dentro da mesma rede virtual.
     
4. **Clique em Create para criar o grupo de destino.**
   - Após preencher os dados, clique em "Create" para criar o Target Group. Esse grupo será utilizado pelo Load Balancer para distribuir o tráfego.

> **Observação**: O Target Group é essencial para definir quais instâncias receberão o tráfego. Certifique-se de configurá-lo corretamente para garantir o balanceamento adequado.

---

### 7.2 Criar o Load Balancer

1. **Vá para Load Balancers no Console de Gerenciamento da AWS.**
   - Acesse a seção de Load Balancers para gerenciar os balanceadores de carga.

2. **Clique em Create Load Balancer e selecione Application Load Balancer.**
   - O Application Load Balancer (ALB) é adequado para aplicações web, pois lida bem com tráfego HTTP e HTTPS, além de permitir rotear com base em diferentes condições.

3. **Preencha as configurações conforme abaixo:**
   - **Name**: `wordpress-lb`
     - Nome do seu Load Balancer. O nome "wordpress-lb" identifica claramente o balanceador que você está criando.
   - **Scheme**: `Internet-facing`
     - O Load Balancer será acessível da internet, permitindo que usuários externos acessem o serviço.
   - **IP address type**: `IPv4`
     - A escolha do tipo de endereço IP. Para a maioria das implementações, o IPv4 é utilizado.
   - **VPC**: Selecione a VPC que você criou anteriormente
     - Escolha a mesma VPC que você configurou anteriormente para garantir que o Load Balancer e as instâncias EC2 estejam na mesma rede.
   - **Availability Zones**: Selecione as duas zonas de disponibilidade e suas sub-redes públicas
     - Isso garante que o Load Balancer distribua o tráfego entre diferentes zonas de disponibilidade, aumentando a disponibilidade e a redundância.
   - **Security Groups**: Selecione o Security Group `LoadBalancer-SecurityGroup`
     - O Security Group controla o tráfego de rede. Certifique-se de usar o grupo de segurança adequado para o Load Balancer.

4. **Em Listeners and routing, selecione o grupo de destino `wordpress-tg` que você criou anteriormente.**
   - Isso define o Target Group que o Load Balancer usará para rotear o tráfego para as instâncias EC2.

5. **Clique em Create load balancer para finalizar a criação do Load Balancer.**
   - Clique em "Create" para concluir a configuração do seu Load Balancer.

> **Observação**: O Load Balancer distribui automaticamente o tráfego entre as instâncias EC2. Ele é fundamental para garantir alta disponibilidade e escalabilidade do seu serviço web, redirecionando o tráfego de maneira eficiente para as instâncias saudáveis.

---

## 8. Configuração do Auto Scaling Group

### 8.1 Criar e Configurar o Auto Scaling Group

1. **No menu à esquerda, vá em Auto Scaling Groups e clique em Create Auto Scaling group.**
   - Acesse a seção de Auto Scaling Groups para criar um novo grupo que irá automaticamente ajustar o número de instâncias EC2 com base na demanda.

2. **Preencha as configurações conforme abaixo:**
   - **Auto Scaling group name**: `wordpress-asg`
     - Nome do seu Auto Scaling Group. Neste caso, o nome "wordpress-asg" é escolhido para indicar que é responsável pela escalabilidade do WordPress.
   - **Launch template**: Escolha o Launch template que você criou anteriormente (`wordpress-temp`)
     - O Launch template que você criou no passo anterior (com configurações da instância EC2) será utilizado para lançar novas instâncias conforme a demanda.
   - **VPC**: Selecione a VPC que você criou
     - Escolha a VPC na qual suas instâncias EC2 e o Load Balancer estão localizados para garantir a comunicação entre os recursos.
   - **Availability Zones**: Selecione as zonas privadas da sua VPC
     - Escolha as zonas de disponibilidade privadas na VPC onde as instâncias EC2 serão lançadas, proporcionando maior disponibilidade e redundância.
   - **Attach to an existing load balancer**: Marque essa opção e selecione o Load Balancer `wordpress-lb` e o grupo de destino `wordpress-tg`
     - O Auto Scaling Group será associado ao Load Balancer `wordpress-lb` e ao grupo de destino `wordpress-tg`, garantindo que as instâncias lancem automaticamente com balanceamento de carga adequado.
   - **Health checks**: Ative a opção Elastic Load Balancing health checks
     - Os health checks irão monitorar a saúde das instâncias através do Load Balancer. Caso uma instância esteja com problemas, o Auto Scaling Group substituirá automaticamente a instância com falha.
   - **Desired capacity**: `2`
     - A capacidade desejada define o número de instâncias que o Auto Scaling Group deve manter em execução. Neste caso, definimos para 2 instâncias.
   - **Minimum capacity**: `1`
     - A capacidade mínima define o número mínimo de instâncias que devem estar sempre disponíveis. Neste caso, 1 instância é a mínima.
   - **Maximum capacity**: `2`
     - A capacidade máxima define o número máximo de instâncias permitidas no Auto Scaling Group. Aqui, o máximo é 2 instâncias, limitando o dimensionamento da aplicação.

3. **Clique em Next para configurar as notificações, se necessário.**
   - Se necessário, você pode configurar notificações por e-mail para alertar sobre eventos no Auto Scaling Group, como escalonamentos ou falhas.

4. **Configure as notificações por email, caso desejado.**
   - Se optar por configurar notificações, defina as configurações de e-mail para que você seja informado sempre que houver alterações no número de instâncias ou em outros eventos do Auto Scaling Group.

5. **Clique em Create Auto Scaling group para finalizar a criação do Auto Scaling Group.**
   - Após revisar todas as configurações, clique em "Create" para finalizar a criação do Auto Scaling Group. O grupo será criado e começará a operar conforme as configurações definidas.

> **Observação**: O Auto Scaling Group é essencial para garantir que sua aplicação tenha a quantidade certa de instâncias rodando, com base na demanda. Ele ajusta automaticamente o número de instâncias, garantindo alta disponibilidade e desempenho ideal do WordPress.

---

## 9. Verificação e Validação

## 9.1 Verificar o status do Load Balancer

1. **Aguarde as instâncias EC2 serem inicializadas e o Auto Scaling Group realizar a distribuição das instâncias.**
   - Após a criação do Auto Scaling Group, as instâncias EC2 serão inicializadas e distribuídas de acordo com a configuração. O processo pode levar alguns minutos para ser concluído.

2. **Vá até o Load Balancer no Console de EC2 e verifique se o estado do Load Balancer está como Active.**
   - Acesse o Console de EC2 e navegue até a seção de Load Balancers. Verifique se o Load Balancer que você criou (`wordpress-lb`) está ativo e pronto para receber tráfego.

3. **Certifique-se de que o status de saúde das instâncias no Target Group também esteja saudável (Healthy).**
   - No Console de EC2, em Target Groups, verifique o status de saúde das instâncias associadas ao grupo de destino (`wordpress-tg`). As instâncias devem aparecer como "Healthy" para garantir que estão operando corretamente e prontas para receber solicitações.

## 9.2 Verificar o acesso à aplicação pelo Load Balancer

1. **Copie o DNS name do Load Balancer gerado.**
   - No Console de EC2, na seção de Load Balancers, copie o DNS name que foi gerado para o seu Load Balancer.

2. **Abra o seu navegador e cole o DNS name do Load Balancer na barra de endereços.**
   - No seu navegador, cole o DNS name do Load Balancer copiado na barra de endereços e pressione Enter.

3. **Se tudo estiver configurado corretamente, você deverá ver a página inicial do WordPress.**
   - Caso tudo tenha sido configurado corretamente, você verá a página inicial do WordPress. Isso indica que sua aplicação está sendo servida através do Load Balancer e das instâncias EC2.

## 9.3 Acessar as instâncias EC2 pelo SSM

1. **Vá até o SSM (AWS Systems Manager) no Console de Gerenciamento da AWS.**
   - Acesse o Console de Gerenciamento da AWS e vá até o AWS Systems Manager (SSM), onde você pode gerenciar e acessar suas instâncias EC2 de forma remota.

2. **No menu à esquerda, clique em Instances & Nodes.**
   - No menu lateral esquerdo, clique em "Instances & Nodes" para visualizar todas as instâncias EC2 gerenciadas pelo SSM.

3. **Selecione Managed Instances e procure pelas instâncias EC2 que estão sendo gerenciadas pelo SSM.**
   - Em "Managed Instances", procure pelas instâncias EC2 que estão configuradas para serem gerenciadas pelo SSM. Essas instâncias devem aparecer na lista.

4. **Clique na instância que deseja acessar e, em seguida, clique em Connect.**
   - Selecione a instância EC2 que você deseja acessar e clique em "Connect" para iniciar a conexão.

5. **Escolha a opção Session Manager para iniciar uma sessão na instância EC2 diretamente pelo console, sem a necessidade de uma chave SSH.**
   - Selecione a opção "Session Manager" para abrir uma sessão interativa diretamente no console. Isso permite acessar a instância sem precisar de uma chave SSH, facilitando a administração.



