# Dropsonde Plugin API

Each metric or family of metrics is exposed by a single metrics plugin. This is
a Ruby file that lives in `lib/dropsonde/metrics` and defines a single class
named after its filename. For example, if you wanted to write a plugin to gather
Puppet Server JVM settings, you might create the class `Dropsonde::Metrics::Jvm`
in the Ruby file named `lib/dropsonde/metrics/jvm.rb`.

Hooks are defined as a series of class methods. A skeleton of a metric plugin,
showing the available hooks, looks like so, and the hooks are all described below.

``` ruby
class Dropsonde::Metrics::Demo
  def self.initialize_demo
    # Require any libraries needed here -- no need to load puppet or puppetdb;
    # they're already loaded. This hook is named after the class name.
    # All plugins are initialized at startup before any metrics are generated.
  end

  def self.description
    # Return a string explaining what the metric generates.
  end

  def self.schema
    # return an array of hashes of a partial schema to be merged into the complete schema
  end

  def self.setup
    # run just before generating this metric
  end

  def self.run
    # return an array of hashes representing the data to be merged into the combined checkin
  end

  def self.example
    # this method is used to generate a table filled with randomized data to
    # make it easier to write data aggregation queries without access to the
    # actual private data that users have submitted.
  end

  def self.cleanup
    # run just after generating this metric
  end
end

```

## Flow of Execution

When Dropsonde starts, it first iterates through and loads each (non-blacklisted)
plugin and invokes its [initializer](#self.initialize_example). This initializer
is run unconditionally regardless of the operation being performed.

Next, depending the operation being performed, all plugins are iterated through
in slightly different manners.

For the `list`, `schema`, and `example` commands, Dropsonde will simply iterate
and invoke each appropriate hook.

For the `preview` and `submit` commands, Dropsonde will iterate plugins and invoke
in this order:

1. `self.setup`
1. `self.run`
1. `self.cleanup`

## Helper Methods

The `puppet` library is loaded, so you can use it to gather any information about
that master you'd like. Some examples include:

* `Puppet.lookup(:environments)`
* `Puppet.settings`

We've also loaded the [PuppetDB](https://github.com/voxpupuli/puppetdb-ruby)
library. It's initialized with that master's own configuration and exposed to you
as `Dropsonde.puppetDB`. So for example, you could could get a list of all
classes used in the infrastructure with this PQL query:

```
results = Dropsonde.puppetDB.request( '',
    'resources[type, title] { type = "Class" }'
).data
```

The list of public Forge modules is available to you as  `Dropsonde::Cache.modules`.
You should make liberal use of this list to ensure that you only collect data
about public modules, since the name of private modules can sometimes include
private information.

And finally, each module's existing `.name`, `.version`, etc methods have been
supplemented with

* `mod.forge_slug`
    * Return the full name of the module, formatted as `author-name` to match the
      Forge API.
* `mod.forge_module?`
    * Returns a Boolean value indicating whether the module exists on the Forge.

## Optional Hooks

These methods are provided for convenience as a way to logically group code. It
is possible to do initialization, setup, and teardown all in the `.run` hook, but
this separation allows you to make your code more straightforward to read if you'd
like to.

### `self.initialize_example`

* parameters: none
* return value: none

This method is the initializer. It should be named after the metric class. So in
the `Dropsonde::Metrics::Jvm` example, it would be called `self.initialize_jvm`.

When Dropsonde starts up, it first iterates through and runs each plugin's
initializer. You can use it to `require` libraries, for example. Remember that
it's invoked regardless of run mode, so you may not want to perform heavy and
unnecessary operations here.


### `self.setup`

* parameters: none
* return value: none

This method is invoked just prior to the `self.run` hook. Use this for any setup
that only needs to run when actually gathering the data.


### `self.cleanup`

* parameters: none
* return value: none

This method is invoked just after to the `self.run` hook. Use this to clean up
temporary files or any other debris left behind.



## Required Hooks

### `self.description`

* parameters: none
* return value: String description of metric

This method is used by the `list` and `preview` operations to describe what data
this plugin collects. It should be complete but concise.


### `self.schema`

* parameters: none
* return value: Array of Hashes describing the partial schema of your plugin

BigQuery schemas are described via [JSON files](https://cloud.google.com/bigquery/docs/schemas#specifying_a_json_schema_file).
The value returned by this method is a carefully formatted Array object. Each
item in the array is a hash representing a column of the database, or piece of
information you collect.

A simple item in that array might look like this:

``` json
{
    "description": "The number of environments",
    "mode": "NULLABLE",
    "name": "environment_count",
    "type": "INTEGER"
}
```

Note that the _names_ of environments is considered to be sensitive data and
should not be included in a metric unless you simply want to count the number of
people who have `dev`, `staging`, and `prod` (or other well known) environments.

However, we can also get more complex and records can have subkeys, like `.name`
or `.version`. To do that, you add an entry for a `RECORD` type that is `REPEATABLE`.
The `fields` key of that hash is another array that contains items like our first
example. That item would look like:

``` json
{
    "fields": [
        {
            "description": "The module name",
            "mode": "NULLABLE",
            "name": "name",
            "type": "STRING"
        },
        {
            "description": "The module slug (author-name)",
            "mode": "NULLABLE",
            "name": "slug",
            "type": "STRING"
        },
        {
            "description": "The module version",
            "mode": "NULLABLE",
            "name": "version",
            "type": "STRING"
        }
    ],
    "description": "List of modules in all environments.",
    "mode": "REPEATED",
    "name": "modules",
    "type": "RECORD"
}
```

The value returned should be a data object, not a JSON string representation of it.
Note that because we want plugins to be able to copy and paste JSON directly into
this method, [Ruby 2.3.0+ is required](https://rocket-science.ru/hacking/2016/03/09/new-hash-syntax-for-the-rescue).

### `self.example`

* parameters: none
* return value: Array of Hashes containing representative example data

The data collected by Dropsonde is locked away in a private database and
[aggregated](https://github.com/puppetlabs/dropsonde-aggregation)
into non-identifiable public forms. In order to develop the aggregation queries,
developers need access to representative data to work with. This method should
generate randomized but valid examples of data and return that in a full array.

The array should have one item for each metric you gather, formatted like so:

``` ruby
[
    :column_name => value,
    :column_name => value,
    #...
]
```

The data object generated must match the schema your plugin exports. For example,
a corresponding item for the `environment_count` metric above might look like:

``` ruby
[
    :environment_count => rand(100),
]
```

`REPEATED RECORD` entries will then be a name pointing to another array of hashes.
The more complex example of the `modules` metric above might be the following,
which just generates a random list of public module names and applies a random
version number to each.


``` ruby
[
  :modules => Dropsonde::Cache.modules
                              .sample(rand(100))
                              .map {|item| {
                                :name    => item.split('-').last,
                                :slug    => item,
                                :version => versions.sample,
                              }},
]
```


### `self.run`

* parameters: none
* return value: Array of Hashes containing actual metric data

This method is the meat of the metric. It should calculate and return live data,
following the same format as the `example` method above. It is also validated
against your schema, so it must match.

An example of the `environment_count` example might look like:

``` ruby
[
    :environment_count => Puppet.lookup(:environments).count,
]
```

The `modules` metric is more complex and includes logic to only report on public
modules using our cached module list.

``` ruby
environments = Puppet.lookup(:environments).list.map{|e|e.name}
modules = environments.map do |env|
  Puppet.lookup(:environments).get(env).modules.map do|mod|
    next unless mod.forge_module?

    {
      :name    => mod.name,
      :slug    => mod.forge_slug,
      :version => mod.version,
    }
  end
end.flatten.compact.uniq
```
