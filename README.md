Guard::Rsync
===========

Rsync guard allows to automatically sync directories when source file
changes.

Focus of this guard task is to sync directories while excluding
autogenerated files and their sources.

Install
-------

Please be sure to have [Guard](https://github.com/guard/guard) installed before continue.

Install the gem:

    $ gem install guard-rsync

Add it to your Gemfile (inside development group):

``` ruby
gem 'guard-rsync'
```

Usage
-----

Please read [Guard usage doc](https://github.com/guard/guard#readme)

Guardfile
---------

The following example pairs the coffeescript guard with a rsync guard.

``` ruby
group(:build_my_app) do
  guard('rsync', {
    :input => 'apps_src/my_app',
    :output => 'apps',
    :excludes => [ '*.coffee', '*.js' ],
    :extra => [ '--bwlimit=50' ],
    :run_group_on_start => true
  }) do
    watch(%r{^apps_src/my_app/(.+\.(?!coffee)(.*)|[^.]+)$})
  end

  guard 'coffeescript', :input => 'apps_src/my_app', :output => 'apps/my_app'
end
```

Author
------

[Kristofor Selden](https://github.com/kselden)

