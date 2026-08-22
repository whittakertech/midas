class ApplicationRecord < ActiveRecord::Base
  # `primary_abstract_class` arrived in Rails 7.0. The 6.1 matrix lane needs
  # the older spelling, which is what it sets under the hood.
  if respond_to?(:primary_abstract_class)
    primary_abstract_class
  else
    self.abstract_class = true
  end
end
