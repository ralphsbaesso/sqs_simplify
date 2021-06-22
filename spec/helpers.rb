# frozen_string_literal: true

module Helpers
  def clear_variables(obj, *variables)
    obj.instance_variables.each do |variable|
      next unless variables.map(&:to_sym).include? variable

      obj.instance_variable_set variable, nil
    end
  end
end
