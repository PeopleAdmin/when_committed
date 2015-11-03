require 'active_record'
require 'when_committed'

describe "WhenCommitted" do

  before(:all) do
    ActiveRecord::Base.establish_connection(adapter: :nulldb)
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Schema.define do
      create_table(:widgets, id: false) do |t|
        t.string  :name
        t.integer :size
      end
    end
  end

  it "provides a #when_committed method" do
    sample_class = Class.new(ActiveRecord::Base)
    model = sample_class.new
    expect(model).not_to respond_to(:when_committed)
    sample_class.send :include, WhenCommitted::ActiveRecord
    expect(model).to respond_to(:when_committed)
  end

  describe "#when_committed" do
    before do
      Backgrounder.reset
    end
    let(:model) { Widget.new }

    it "runs the provided block immediately when no transaction" do
      model.action_that_needs_follow_up_after_commit
      expect(Backgrounder.jobs).to eq [:important_work]
    end

    it "does not run the provided block until the transaction is committed" do
      Widget.transaction do
        model.action_that_needs_follow_up_after_commit
        expect(Backgrounder.jobs).to be_empty
        model.save
        expect(Backgrounder.jobs).to be_empty
      end
      expect(Backgrounder.jobs).to eq [:important_work]
    end

    it "does not run the provided block if the transaction is rolled back" do
      begin
        Widget.transaction do
          model.action_that_needs_follow_up_after_commit
          model.save
          raise Catastrophe
        end
      rescue Catastrophe
      end
      expect(Backgrounder.jobs).to be_empty
    end

    it "allows you to register multiple after_commit blocks" do
      Widget.transaction do
        model.action_that_needs_follow_up_after_commit
        model.another_action_with_follow_up
        model.save
      end
      expect(Backgrounder.jobs).to eq [:important_work,:more_work]
    end

    it "does not run a registered block more than once" do
      Widget.transaction do
        model.action_that_needs_follow_up_after_commit
        model.save
      end
      Widget.transaction do
        model.save
      end
      expect(Backgrounder.jobs).to eq [:important_work]
    end
  end
end

class Widget < ActiveRecord::Base
  include WhenCommitted::ActiveRecord
  def action_that_needs_follow_up_after_commit
    when_committed { Backgrounder.enqueue :important_work }
  end
  def another_action_with_follow_up
    when_committed { Backgrounder.enqueue :more_work }
  end
end

class Backgrounder
  def self.enqueue job
    jobs << job
  end

  def self.jobs
    @jobs ||= []
  end

  def self.reset
    @jobs = []
  end
end

class Catastrophe < StandardError; end
