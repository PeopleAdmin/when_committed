# WhenCommitted

Provides `#when_commited` to run instance-specific code in an ActiveRecord
`#after_commit` callback.

This is very useful for things like enqueuing a background job that is triggered
by a model changing state. Usually, it is not sufficient to enqueue the job in
an `#after_save` hook, because there is always the chance that the save will be
rolled back (or that the job gets picked up before the save is committed). You
could try moving that code to an `after_commit` callback, but then you do not
have access to the `#changes` to your model (they have already been applied), so
it may be difficult to make decisions on whether to enqueue the job or not.

## Installation

Add this line to your application's Gemfile:

    gem 'when_committed'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install when_committed

## Usage

Include the WhenCommitted::ActiveRecord module in your model:

    class Post < ActiveRecord::Base
      include WhenCommitted::ActiveRecord
    end

Call `#when_committed` with a block of code that should run when the transaction
is committed:

    def update_score(new_score)
      self.score = new_score
      when_committed { Resque.enqueue(RecalculateAggregateScores, self.id) }
    end

Note that the block will run immediately when not in a transaction.

## Contributing

1. [Fork it](https://github.com/PeopleAdmin/when_committed/fork_select)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. [Create new Pull Request](https://github.com/PeopleAdmin/when_committed/pull/new/master)
