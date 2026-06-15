# SqsSimplify

Esta gem tem como objetivo utilizar o sistema de fila AWS SQS.
Com 3 papeis principais principais:
* **SqsSimplify::Scheduler**: Envia mensagem para fila.
* **SqsSimplify::Consumer**: Consumir mensagem para fila. 
* **SqsSimplify::Job**: Envia e consumir mensagem para fila. 


## Instalação

Adicione esta linha na Gemfile da aplicação:

```ruby
gem 'sqs_simplify'
```

E execute:

    $ bundle install
___

## Como usar
### 1. Configuração Inicial

Crie um arquivo de configuração para ser carregado na inicialização da aplicação.

Exemplo: *sqs_simplify.rb*

Se for uma aplicação **Rails**, crie em *config/initializers/sqs_simplify.rb*.

Neste arquivo você pode configurar as credencial da AWS e outras customizações.

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

O componente Scheduler tem a funcionalidade de enviar mesagens para a fila SQS.

Seu foco principal é na utilização de barramento de fila entre duas aplicações distintas.

Por exemplo: A aplicação **A** tem um Scheduler que envia mesagem para a fila SQS mas quem vai consumir esta mensagem será a aplicação **B**.

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

### 2. Consumer

O componente Consumer tem a funcionalidade de consumir mesagens para a fila SQS.

Seu foco principal tambeḿ é na utilização de barramento de fila entre duas aplicações distintas.

Por exemplo: A aplicação **B** tem um Consumer que solicita mesagem da fila SQS que foi enviada pela aplicação **A**.

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


### 2. Job

O componente Job tem a funcionalidade de enviar e consumir mensagens da fila SQS da mesma aplicação.

Diferente dos outros componentes, seu foco **não** é na utilização de barramento de fila.

Por exemplo: Sua aplicação tem uma classe **Report** que gera um relatório.
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
Toda configuração feito na class SqsSimplify será aplicado em todos os componentes.

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

Com esta configuração todos os componentes, Scheduler, Consumer e Job, terão a mesma configuração.

Todos terão acesso as filas SQS de *us-east-2*

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

### 1.1 Hooks

**resolver_exception:** É invocado sempre que ocorrer uma **Exception** na sua aplicação.
Disponibiliza dois parâmetro:
* **primeiro parâmetro** é uma **Exception**. 
* **segundo parâmetro** pode variar de acordo com o componente e a onde ocorreu a **Exception**.

**message_not_deleted:** É invocado quando um Job ou Consumer pega uma mesagem da fila SQS não não consegue apagá-la.
Há dois principais motivo para ocorrer:
* **Exception**: quando ocorre uma **Exception**. Obs: também será invocado o hook **resolver_exception**.
* **Default visibility timeout**: A mensagem não foi processada no tempo definido.

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

Para projeto Rails você pode carragar a aplicação antes da invocação da GEM.
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

### 1. Comandos
Para ver opções do comando execute no diretório do arquivo:

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
## Contribuição

https://github.com/ralphsbaesso/sqs_simplify.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

