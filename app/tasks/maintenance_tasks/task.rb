# frozen_string_literal: true

module MaintenanceTasks
  # Base class that is inherited by the host application's task classes.
  class Task
    extend ActiveSupport::DescendantsTracker

    class NotFoundError < NameError; end

    class << self
      attr_reader :throttle_condition, :throttle_backoff

      # Finds a Task with the given name.
      #
      # @param name [String] the name of the Task to be found.
      #
      # @return [Task] the Task with the given name.
      #
      # @raise [NotFoundError] if a Task with the given name does not exist.
      def named(name)
        name.constantize
      rescue NameError
        raise NotFoundError.new("Task #{name} not found.", name)
      end

      # Returns a list of concrete classes that inherit from the Task
      # superclass.
      #
      # @return [Array<Class>] the list of classes.
      def available_tasks
        load_constants
        descendants
      end

      # Make this Task a task that handles CSV.
      #
      # An input to upload a CSV will be added in the form to start a Run. The
      # collection and count method are implemented.
      def csv_collection
        include(CsvCollection)
      end

      # Processes one item.
      #
      # Especially useful for tests.
      #
      # @param item the item to process.
      def process(item)
        new.process(item)
      end

      # Returns the enumerator builder for this Task.
      #
      # Especially useful for tests.
      #
      # @return the enumerator builder.
      def enumerator_builder
        new.enumerator_builder
      end

      # Returns the collection for this Task.
      #
      # Especially useful for tests.
      #
      # @return the collection.
      def collection
        new.collection
      end

      # Returns the count of items for this Task.
      #
      # Especially useful for tests.
      #
      # @return the count of items.
      def count
        new.count
      end

      # Define throttling for this Task.
      #
      # @param condition [Proc] defines the condition under which the Task
      #   should be throttled.
      # @param backoff [ActiveSupport::Duration] optionally, a custom backoff
      #   can be specified. This is the time to wait before retrying the Task.
      #   If no value is specified, it defaults to 30 seconds.
      def throttle_on(condition, backoff: 30.seconds)
        @throttle_condition = condition
        @throttle_backoff = backoff
      end

      private

      def load_constants
        namespace = MaintenanceTasks.tasks_module.safe_constantize
        return unless namespace
        namespace.constants.map { |constant| namespace.const_get(constant) }
      end
    end

    # @api private
    ActiveRecordEnumeratorBuilder = Struct.new(:relation) do
      def enumerator(context:)
        JobIteration::EnumeratorBuilder.new(nil).active_record_on_records(
          relation,
          cursor: context.cursor,
        )
      end
    end
    private_constant :ActiveRecordEnumeratorBuilder

    # @api private
    ArrayEnumeratorBuilder = Struct.new(:array) do
      def enumerator(context:)
        JobIteration::EnumeratorBuilder.new(nil).build_array_enumerator(
          array,
          cursor: context.cursor,
        )
      end
    end
    private_constant :ArrayEnumeratorBuilder

    def enumerator_builder
      collection = self.collection

      case collection
      when ActiveRecord::Relation
        ActiveRecordEnumeratorBuilder.new(collection)
      when Array
        ArrayEnumeratorBuilder.new(collection)
      else
        raise ArgumentError, "#{self.class.name}#collection must be either "\
          'an Active Record Relation, or Array.' # TODO: update
        # If you want CSVs, do this
        # If you want custom enum, do this
      end
    end

    # Placeholder method to raise in case a subclass fails to implement the
    # expected instance method.
    #
    # @raise [NotImplementedError] with a message advising subclasses to
    #   implement an override for this method.
    def collection
      raise NoMethodError, "#{self.class.name} must implement `collection`."
    end

    # Placeholder method to raise in case a subclass fails to implement the
    # expected instance method.
    #
    # @param _item [Object] the current item from the enumerator being iterated.
    #
    # @raise [NotImplementedError] with a message advising subclasses to
    #   implement an override for this method.
    def process(_item)
      raise NoMethodError, "#{self.class.name} must implement `process`."
    end

    # Total count of iterations to be performed.
    #
    # Tasks override this method to define the total amount of iterations
    # expected at the start of the run. Return +nil+ if the amount is
    # undefined, or counting would be prohibitive for your database.
    #
    # @return [Integer, nil]
    def count
    end

    # Return condition under which the Task should throttle.
    #
    # @return [Proc, nil]
    def throttle_condition
      self.class.throttle_condition
    end

    # Return throttle backoff defined for the Task.
    #
    # @return [ActiveSupport::Duration, nil]
    def throttle_backoff
      self.class.throttle_backoff
    end
  end
end
