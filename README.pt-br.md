# SqsSimplify

Esta gem tem como objetivo utilizar o sistema de fila AWS SQS.
Com 3 papeis principais principais:
* **SqsSimply::Scheduler**: Envia mensagem para fila.
* **SqsSimply::Consumer**: Consume mensagem para fila. 
* **SqsSimply::Job**: Envia e consume mensagem para fila. 


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

Se for uma aplicação **Rails**, crie em *cong/initializes/sqs_simplify.rb*.

Neste arquivo você pode configurar as credencial da AWS e outras customizações.

```ruby
# sqs_simplify.rb

SqsSimplify.configure do |config|
  config.access_key_id = ENV['AWS_ACCESS_KEY_ID']
  config.secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.region = 'us-east-1'

  config.queue_prefix = Rails.env # optional
  config.queue_sufix = 'my_application_name' # optional
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
    MyScheduler.send_message(message: message, delay: delay)
  end
end

# run now
WheelFactory.send_now # "8685d169-f4a0-476b-b970-39ee055f957b"

# run after 2 minutes
WheelFactory.send_later(120) # "5ebd6a74-8571-43e2-a9c8-7866b7598765"

```

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

O componente Job tem a funcionalidade de enviar e consumer mensagens da fila SQS da mesma aplicação.

Diferente dos outros componentes, seu foco **não** é na utilização de barramento de fila.

Por exemplo: Sua aplicação tem uma classe **Report** com um método **monthly_report**.
Este método demora muita para ser executado.
Então você pode agendar este método para ser executado mais tarde.

```ruby
# app/jobs/report.rb

class Report < SqsSimplify::Job
  
  def monthly_report(list)
    # you logic here
    PersistReport.save(list)
  end
  
end

list = # many data
  
# schedule job
# run now
Report.monthly_report(list).later # "76107a55-43d9-4f2e-b449-02c329a51692"

# run after 3 minutes
Report.monthly_report(list).later(180) # "be6837d5-c11f-495c-a03e-cb093011f1d0"

# run after 10 minutes
Report.monthly_report(list).later(600) # "004ebc02-15be-424d-8898-802033b7fca8"

# run now
# attention, it will not be scheduled
Report.monthly_report(list).now # :executed
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

**message_not_deleted:** É invocado quando a mesagem não é apagada da File SQS.
Há dois principais motivo para ocorrer:
* **Exception**: quando ocorre uma **Exception**. Obs: também será invocado o hook **resolver_exception**.
* **Default visibility timeout**: A mensagem não foi processada no tempo definido.

```ruby
# sqs_simplify.rb

SqsSimplify.configure do |config|
  config.hooks.resolver_exception do |exception, args|
    Event.add "SqsSimplify => #{exception.message}",
              type: :exception,
              args: args.as_json,
              backtrace: exception.backtrace
  rescue StandardError => e
    warn e.message
    warn e.backtrace
  end

  config.hooks.message_not_deleted do |consumer|
    Event.add 'Mensagem SQS não deletada!', type: :message_not_deleted, consumer: consumer
  end

  config.hooks.after_fork do
    puts "\t***Initializing Rails project***\n"
    Rails.application.eager_load!
  end
end
```

___

## Contribuição

https://github.com/ralphsbaesso/sqs_simplify.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the SqsSimplify project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/sqs_simplify/blob/master/CODE_OF_CONDUCT.md).
