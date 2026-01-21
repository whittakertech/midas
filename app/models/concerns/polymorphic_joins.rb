# frozen_string_literal: true

module PolymorphicJoins
  extend ActiveSupport::Concern

  included do
    define_polymorphic_joins!
  end

  class_methods do
    def define_polymorphic_joins!
      reflect_on_all_associations(:belongs_to).each do |assoc|
        next unless assoc.options[:polymorphic]

        assoc_name = assoc.name
        method_name = :"joins_#{assoc_name}"

        next if singleton_class.method_defined?(method_name)

        define_singleton_method(method_name) do |klass|
          unless join_allowed?(klass, as: assoc_name)
            raise ArgumentError, "#{klass.name} must declare has_one/has_many as: :#{assoc_name}"
          end

          source = arel_table
          target = klass.arel_table

          joins(
            source.join(target)
                  .on(source["#{assoc_name}_id"].eq(target[:id]))
                  .join_sources
          ).where(source["#{assoc_name}_type"].eq(klass.name))
        end
      end
    end

    private

    def join_allowed?(klass, as:)
      klass.reflect_on_all_associations.any? do |assoc|
        next false unless assoc.options[:as] == as
        next false unless [:has_many, :has_one].include? assoc.macro

        assoc.klass == self
      end
    end
  end
end
