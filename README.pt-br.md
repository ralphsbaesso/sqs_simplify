# SqsSimplify

[![Gem Version](https://badge.fury.io/rb/sqs_simplify.svg)](https://badge.fury.io/rb/sqs_simplify)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.0-red.svg)](https://www.ruby-lang.org)

Uma DSL Ruby de alto nível sobre o `aws-sdk-sqs` para produzir e consumir mensagens do AWS SQS com o mínimo de boilerplate.

Possui 3 papéis principais:
* **SqsSimplify::Scheduler**: Envia mensagens para uma fila.
* **SqsSimplify::Consumer**: Consome mensagens de uma fila.
* **SqsSimplify::Job**: Envia e consome mensagens de uma fila.

> 🇺🇸 An English version of this document is available at [README.md](README.md).

## Sumário

* [Requisitos](#requisitos)
* [Instalação](#instalação)
* [Como usar](#como-usar)
  * [Configuração Inicial](#1-configuração-inicial)
  * [Scheduler](#2-scheduler)
  * [Consumer](#3-consumer)
  * [Job](#4-job)
* [Configurações](#configurações)
  * [Configuração Global](#1-configuração-global)
  * [Hooks](#2-hooks)
* [Processo Background](#processo-background)
* [Recursos avançados](#recursos-avançados)
* [Desenvolvimento](#desenvolvimento)
* [Contribuição](#contribuição)
* [Licença](#licença)

## Requisitos

* Ruby `>= 3.0.0`
* Dependências de runtime (instaladas automaticamente junto com a gem):
  * [`aws-sdk-sqs`](https://rubygems.org/gems/aws-sdk-sqs) `~> 1.116`
  * [`parallel`](https://rubygems.org/gems/parallel) `~> 2.1`

Você também precisa de credenciais AWS válidas com acesso ao SQS.

## Instalação

Adicione esta linha na Gemfile da aplicação:

```ruby
gem 'sqs_simplify'
```

E execute:

    $ bundle install

Ou instale você mesmo com:

    $ gem install sqs_simplify
___

## Como usar
### 1. Configuração Inicial

Crie um arquivo de configuração para ser carregado na inicialização da aplicação.

Exemplo: *sqs_simplify.rb*

Se for uma aplicação **Rails**, crie em *config/initializers/sqs_simplify.rb*.

Neste arquivo você pode configurar as credenciais da AWS e outras customizações.

```ruby
# sqs_simplify.rb

SqsSimplify.configure do |config|
  config.access_key_id = ENV['AWS_ACCESS_KEY_ID']
  config.secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.region = 'us-east-1'

  config.queue_prefix = Rails.env # optional
  config.queue_suffix = 'my_application_name' # optional
end
```
___


### 2. Scheduler

O componente Scheduler é responsável por enviar mensagens para a fila SQS.

Seu foco principal é na utilização de uma fila como barramento entre duas aplicações distintas.

Por exemplo: a aplicação **A** tem um Scheduler que envia mensagem para a fila SQS, mas quem vai consumir esta mensagem será a aplicação **B**.

```ruby
# app/jobs/my_scheduler

class MyScheduler < SqsSimplify::Scheduler
end


# app/model/wheel_factory.rb

class WheelFactory
  def send_now
    message = { wheels: ['back_wheel', 'front_wheel'], type: 'motorcycle' }
    MyScheduler.send_message(message: message)
  end
  
  def send_later(delay)
    message = { wheels: ['back_wheel', 'front_wheel'], type: 'motorcycle' }
    MyScheduler.send_message(message: message, after: delay)
  end
end


wheel_factory = WheelFactory.new

# run now
wheel_factory.send_now # "8685d169-f4a0-476b-b970-39ee055f957b"

# run after 2 minutes
wheel_factory.send_later(120) # "5ebd6a74-8571-43e2-a9c8-7866b7598765"

```

#### `group_id`

O parâmetro `group_id` é enviado ao SQS como `message_group_id`. Informe-o em
`send_message`:

```ruby
MyScheduler.send_message(message: message, group_id: 'tenant-123')
```

Seu significado depende do tipo de fila:

* **Filas FIFO**: o SQS exige `message_group_id`. Mensagens com o mesmo
  `group_id` são processadas em ordem (FIFO).
* **Filas standard**: o `message_group_id` é usado como identificador de
  *tenant* para o recurso de [fair queues](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-fair-queues.html),
  que mitiga o impacto de *noisy neighbor* em filas multi-tenant. Aqui ele
  **não** garante ordenação — serve apenas para agrupar mensagens por tenant.

Se omitido (`nil`), nenhum `message_group_id` é enviado.

### 3. Consumer

O componente Consumer é responsável por consumir mensagens da fila SQS.

Seu foco principal também é na utilização de uma fila como barramento entre duas aplicações distintas.

Por exemplo: a aplicação **B** tem um Consumer que solicita mensagens da fila SQS que foram enviadas pela aplicação **A**.

```ruby
# app/jobs/motorcycle_assembler.rb

class MotorcycleAssembler < SqsSimplify::Consumer
  
  def perform
    # your logic here
    # your object has "message" method with data of sqs_message
    p message # {:wheels=>["back_wheel", "front_wheel"], :type=>"motorcycle"}
  end
  
end

```


### 4. Job

O componente Job é responsável por enviar e consumir mensagens da fila SQS dentro da mesma aplicação.

Diferente dos outros componentes, seu foco **não** é na utilização de uma fila como barramento.

Por exemplo: sua aplicação tem uma classe **Report** que gera um relatório.
Este processamento demora muito para ser executado.
Então você pode agendar a execução para mais tarde.

O método de negócio **deve** se chamar `perform`.

```ruby
# app/jobs/report.rb

class Report < SqsSimplify::Job
  
  def perform(list)
    # your logic here
    PersistReport.save(list)
  end
  
end

list = # many data

# enfileira para execução posterior
Report.perform_later(list) # "76107a55-43d9-4f2e-b449-02c329a51692"

# enfileira com atraso de 180 segundos
Report.new_job(after: 180).perform_later(list) # "be6837d5-c11f-495c-a03e-cb093011f1d0"

# executa inline, sem enfileirar
# atenção, não será agendado
Report.perform(list) # :executed
```

___

## Configurações

### 1. Configuração Global

#### SqsSimplify
Toda configuração feita na classe SqsSimplify será aplicada em todos os componentes.

Exemplo:

```ruby
# sqs_simplify.rb

SqsSimplify.configure do |config|
  config.access_key_id = ENV['AWS_ACCESS_KEY_ID']
  config.secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.region = 'us-east-2'

  config.queue_prefix = 'production'
end
```

Com esta configuração todos os componentes — Scheduler, Consumer e Job — terão a mesma configuração.

Todos terão acesso às filas SQS de *us-east-2*

Todos terão o prefixo de *production*


```ruby

class MyScheduler < SqsSimplify::Scheduler
  
end

class MyConsumer < SqsSimplify::Consumer

end

class MyJob < SqsSimplify::Job

end

# same prefix
MyScheduler.queue_name # "production_my_scheduler"
MyConsumer.queue_name # "production_my_consumer"
MyJob.queue_name # "production_my_job"

```

### 2. Hooks

**resolver_exception:** É invocado sempre que ocorrer uma **Exception** na sua aplicação.
Disponibiliza dois parâmetros:
* o **primeiro parâmetro** é uma **Exception**.
* o **segundo parâmetro** pode variar de acordo com o componente e onde ocorreu a **Exception**.

**message_not_deleted:** É invocado quando um Job ou Consumer pega uma mensagem da fila SQS e não consegue apagá-la.
Há dois principais motivos para isso ocorrer:
* **Exception**: quando ocorre uma **Exception**. Obs: também será invocado o hook **resolver_exception**.
* **Default visibility timeout**: a mensagem não foi processada no tempo definido.

```ruby
# sqs_simplify.rb

SqsSimplify.configure do |config|
  config.hooks.resolver_exception do |exception, args|
    logger.info "Exception => #{exception.message}, args => #{args}"
  end

  config.hooks.message_not_deleted do |consumer|
    logger.info "Consumer => #{consumer}"
  end
end
```

___

## Processo Background
### 1. Configuração
Para rodar o processo de consumo deve criar um arquivo de script.
O método `run` roda um loop em foreground que consome as filas até receber
`SIGINT` (Ctrl+C) — não daemoniza o processo.
Exemplo de um arquivo de script nomeado de *sqs_simplify*

```ruby
#!/usr/bin/env ruby

require 'sqs_simplify/command'
SqsSimplify::Command.new(ARGV).run
```

Para projeto Rails você pode carregar a aplicação antes da invocação da GEM.
Exemplo de um arquivo de script nomeado de *bin/sqs_simplify*
```ruby
#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'environment'))
require 'sqs_simplify/command'
SqsSimplify::Command.new(ARGV).run
```

E deve dar permissão de execução.
````bash
$ chmod +x sqs_simplify
````

### 2. Comandos
Para ver as opções do comando, execute no diretório do arquivo:

````bash
$ sqs_simplify -h
Usage: sqs_simplify [options]
    -h, --help                       Show help
    -n, --number_of_workers=workers  Number of unique workers to spawn
    -e, --environment=environment    Environment
        --queues=queues              queues that will be consumed
        --priority                   with priority in the queues
    -f, --fork                       parallel in processes
    -t, --thread                     parallel in threads


````

___

## Recursos avançados

Além do básico apresentado acima, a gem também oferece:

* **`map_queue(nickname, &block)`** — roteia um único Scheduler para filas
  alternativas dinamicamente (`SqsSimplify::Scheduler`).
* **Sobrescrita de destino por chamada** — passe `queue_url:` para `send_message`
  para enviar uma mensagem a uma fila específica no momento da chamada.
* **DSL `set` por classe** — sobrescreve configurações por classe, como o nome da
  fila, o visibility timeout, a serialização (`dump_message`/`load_message`) e mais,
  por exemplo `set :queue_name, 'custom_name'`.
* **Dead-letter queues automáticas** — cada fila ganha uma `<nome>_dead`
  pareada como dead-letter queue.
* **Hooks adicionais** — além de `resolver_exception` e `message_not_deleted`, o
  pipeline também suporta os hooks `before`/`after` (`:each` / `:all`) e `around`.
* **Testes sem AWS** — defina `config.faker = true` para usar o `FakerClient` em
  memória, ou `config.stub_responses = true` para stubar o cliente `aws-sdk-sqs`.

## Desenvolvimento

Após clonar o repositório, instale as dependências e rode a suíte de testes:

```bash
bin/setup                  # instala as dependências
bundle exec rake spec      # roda a suíte de testes completa
bundle exec rubocop        # lint
bin/console                # prompt interativo para experimentar
```

Os testes rodam contra um cliente SQS falso em memória, então nenhum acesso real à
AWS é necessário.

Para instalar esta gem na sua máquina local, rode `bundle exec rake install`. Para
publicar uma nova versão, atualize o número da versão em `lib/sqs_simplify/version.rb`
e então rode `bundle exec rake release`.

## Contribuição

Relatos de bugs e pull requests são bem-vindos no GitHub em
https://github.com/ralphsbaesso/sqs_simplify. Para contribuir:

1. Faça um fork do repositório.
2. Crie um branch de feature (`git checkout -b minha-feature`).
3. Faça commit das suas alterações e garanta que os testes (`bundle exec rake spec`)
   e o linter (`bundle exec rubocop`) passem.
4. Abra um pull request.


## Licença

A gem está disponível como código aberto sob os termos da [Licença MIT](https://opensource.org/licenses/MIT).
