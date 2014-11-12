require 'active_record'
require 'when_committed'

describe "WhenCommitted" do
  before(:all) do
    ActiveRecord::Base.establish_connection :adapter => :nulldb
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Schema.define do
      create_table(:widgets) do |t|
        t.string  :name
        t.integer :size
      end
    end
  end

  it "provides a #when_committed method" do
    sample_class = Class.new(ActiveRecord::Base)
    model = sample_class.new
    model.should_not respond_to(:when_committed)
    sample_class.send :include, WhenCommitted::ActiveRecord
    model.should respond_to(:when_committed)
  end

  describe "#when_committed!" do
    before do
      Backgrounder.reset
    end
    let(:model) { Widget.new }

    context "when not running within a transaction" do
      it "runs the block immediately" do
        model.needs_to_happen
        Backgrounder.jobs.should == [:important_work]
      end
    end

    context "when running within a transaction" do
      it "does not run the provided block until the transaction is committed" do
        Widget.transaction do
          model.needs_to_happen
          Backgrounder.jobs.should be_empty
          model.save
          Backgrounder.jobs.should be_empty
        end
        Backgrounder.jobs.should == [:important_work]
      end
    end

  end

  describe "#when_committed" do
    before do
      Backgrounder.reset
    end
    let(:model) { Widget.new }

    it "runs the provided block after the transaction is committed" do
      model.action_that_needs_follow_up_after_commit
      model.save
      Backgrounder.jobs.should == [:important_work]
    end

    it "does not run the provided block until the transaction is committed" do
      Widget.transaction do
        model.action_that_needs_follow_up_after_commit
        Backgrounder.jobs.should be_empty
        model.save
        Backgrounder.jobs.should be_empty
      end
      Backgrounder.jobs.should == [:important_work]
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
      Backgrounder.jobs.should be_empty
    end

    it "allows you to register multiple after_commit blocks" do
      Widget.transaction do
        model.action_that_needs_follow_up_after_commit
        model.another_action_with_follow_up
        model.save
      end
      Backgrounder.jobs.should == [:important_work,:more_work]
    end

    it "does not run a registered block more than once" do
      Widget.transaction do
        model.action_that_needs_follow_up_after_commit
        model.save
      end
      Widget.transaction do
        model.name = "changed"
        model.save
      end
      Backgrounder.should have(1).job
    end
  end
end

class Widget < ActiveRecord::Base
  include WhenCommitted::ActiveRecord
  def action_that_needs_follow_up_after_commit
    when_committed { Backgrounder.enqueue :important_work }
  end
  def needs_to_happen
    when_committed! { Backgrounder.enqueue :important_work }
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
