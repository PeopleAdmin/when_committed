require 'when_committed/version'
require 'active_record'

module WhenCommitted
  module ActiveRecord
    def self.included(base)
      base.after_commit :run_when_committed_callbacks
      base.after_rollback :clear_when_committed_callbacks
    end

    def when_committed(&block)
      when_committed_callbacks << block
    end

    def when_committed!(&block)
      if ::ActiveRecord::Base.connection.open_transactions != 0
        when_committed(&block)
      else
        block.call
      end
    end

    private

    def when_committed_callbacks
      @when_committed_callbacks ||= []
    end

    def run_when_committed_callbacks
      when_committed_callbacks.each {|cb| cb.call}
      clear_when_committed_callbacks
    end

    def clear_when_committed_callbacks
      when_committed_callbacks.clear
    end
  end
end

