# Minimundo -  Sistema de Informação para Atividades de Extensão Universitária

## Elaboração, implantação, governança e uso de banco

Este projeto simula um sistema de gerenciamento de eventos com múltiplas entidades como salas, atividades, participantes, instrutores, inscrições, materiais, presenças, certificados e muito mais. A base de dados é implementada em PostgreSQL e é inicializada automaticamente via Docker.

## Estrutura do Projeto

- `initdb/init.sql`: Criação de tabelas, tipos e constraints.
- `initdb/populate_data.sql`: População automatizada com dados sintéticos aleatórios.
- `docker-compose.yml`: Define o serviço do banco de dados PostgreSQL.
- 

## Modelagem

![Image](https://github.com/user-attachments/assets/cda8c92a-6b48-46a5-83ba-58bea5f01ab3)

## Requisitos

- [Docker](https://www.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)

## Como executar

1. Clone este repositório:
   
   ```bash
   git clone https://github.com/hmigl/minimundo-bd.git
   cd minimundo-db
   ```

2. Execute e aguarde até a inicialização do projeto
   
   ```bash
   docker-compose down --volumes
   docker-compose up --build
   ```

## Conecte-se a partir de um cliente externo

O banco de dados estará rodando com as seguintes informações:

> - **Host**: `localhost`
> 
> - **Porta**: `5432`
> 
> - **Database**: `eventdb`
> 
> - **Usuário**: `postgres_user`
> 
> - **Senha**: `postgres_pass`



Ferramentas sugeridas: DBeaver, DataGrip.


## Limitações

> 
