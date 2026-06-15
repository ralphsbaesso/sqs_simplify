# SqsSimplify

This gem aims to make working with the AWS SQS queue system easier.
It has 3 main roles:
* **SqsSimplify::Scheduler**: Sends messages to a queue.
* **SqsSimplify::Consumer**: Consumes messages from a queue.
* **SqsSimplify::Job**: Sends and consumes messages from a queue.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sqs_simplify'
```

And then execute:

    $ bundle install
___

## How to use
### 1. Initial Configuration

Create a configuration file to be loaded when the application starts.

Example: *sqs_simplify.rb*

If it is a **Rails** application, create it at *config/initializers/sqs_simplify.rb*.

In this file you can configure your AWS credentials and other customizations.

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

The Scheduler component is responsible for sending messages to the SQS queue.

Its main focus is using a queue as a bus between two distinct applications.

For example: application **A** has a Scheduler that sends a message to the SQS queue, but the one that will consume this message is application **B**.

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

The `group_id` parameter is sent to SQS as `message_group_id`. Provide it in
`send_message`:

```ruby
MyScheduler.send_message(message: message, group_id: 'tenant-123')
```

Its meaning depends on the queue type:

* **FIFO queues**: SQS requires `message_group_id`. Messages with the same
  `group_id` are processed in order (FIFO).
* **Standard queues**: the `message_group_id` is used as a *tenant* identifier
  for the [fair queues](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-fair-queues.html)
  feature, which mitigates the *noisy neighbor* impact in multi-tenant queues.
  Here it does **not** guarantee ordering — it only groups messages by tenant.

If omitted (`nil`), no `message_group_id` is sent.

### 3. Consumer

The Consumer component is responsible for consuming messages from the SQS queue.

Its main focus is also using a queue as a bus between two distinct applications.

For example: application **B** has a Consumer that requests messages from the SQS queue that were sent by application **A**.

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

The Job component is responsible for sending and consuming messages from the SQS queue within the same application.

Unlike the other components, its focus is **not** on using a queue as a bus.

For example: your application has a **Report** class that generates a report.
This processing takes a long time to run.
So you can schedule its execution for later.

The business method **must** be named `perform`.

```ruby
# app/jobs/report.rb

class Report < SqsSimplify::Job
  
  def perform(list)
    # your logic here
    PersistReport.save(list)
  end
  
end

list = # many data

# enqueue for later execution
Report.perform_later(list) # "76107a55-43d9-4f2e-b449-02c329a51692"

# enqueue with a 180 second delay
Report.new_job(after: 180).perform_later(list) # "be6837d5-c11f-495c-a03e-cb093011f1d0"

# run inline, without enqueuing
# note: it will not be scheduled
Report.perform(list) # :executed
```

___

## Configuration

### 1. Global Configuration

#### SqsSimplify
Every configuration made on the SqsSimplify class will be applied to all components.

Example:

```ruby
# sqs_simplify.rb

SqsSimplify.configure do |config|
  config.access_key_id = ENV['AWS_ACCESS_KEY_ID']
  config.secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
  config.region = 'us-east-2'

  config.queue_prefix = 'production'
end
```

With this configuration all components — Scheduler, Consumer and Job — will share the same configuration.

All of them will have access to the SQS queues in *us-east-2*

All of them will have the *production* prefix


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

**resolver_exception:** Invoked whenever an **Exception** occurs in your application.
It provides two parameters:
* the **first parameter** is an **Exception**.
* the **second parameter** may vary depending on the component and where the **Exception** occurred.

**message_not_deleted:** Invoked when a Job or Consumer picks up a message from the SQS queue but is unable to delete it.
There are two main reasons for this to happen:
* **Exception**: when an **Exception** occurs. Note: the **resolver_exception** hook will also be invoked.
* **Default visibility timeout**: the message was not processed within the defined time.

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

## Background Process
### 1. Setup
To run the consuming process you must create a script file.
The `run` method runs a foreground loop that consumes the queues until it
receives `SIGINT` (Ctrl+C) — it does not daemonize the process.
Example of a script file named *sqs_simplify*

```ruby
#!/usr/bin/env ruby

require 'sqs_simplify/command'
SqsSimplify::Command.new(ARGV).run
```

For a Rails project you can load the application before invoking the GEM.
Example of a script file named *bin/sqs_simplify*
```ruby
#!/usr/bin/env ruby

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'environment'))
require 'sqs_simplify/command'
SqsSimplify::Command.new(ARGV).run
```

And you must grant execution permission.
````bash
$ chmod +x sqs_simplify
````

### 2. Commands
To see the command options, run it in the file's directory:

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
## Contributing

https://github.com/ralphsbaesso/sqs_simplify.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
