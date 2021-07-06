# frozen_string_literal: true

module Helpers
  def clear_variables(obj, *variables, all: false)
    if all
      obj.instance_variables.each do |variable|
        obj.instance_variable_set variable, nil
      end
    else
      obj.instance_variables.each do |variable|
        obj.instance_variable_set(variable, nil) if variables.map(&:to_sym).include? variable
      end
    end
  end
end
