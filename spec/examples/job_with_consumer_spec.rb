# frozen_string_literal: true

class JobSlow < SqsSimplify::Job
  def my_method
    # ignore
  end
end

class JobMedium < SqsSimplify::Job
  def my_method
    # ignore
  end
end

class JobFast < SqsSimplify::Job
  def my_method
    # ignore
  end
end
