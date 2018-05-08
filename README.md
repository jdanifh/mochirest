Mochirest
========================================

Mochirest is an REST API framework that runs on top of [mochiweb](https://github.com/mochi/mochiweb)

How to use
----------

### Prerequisites ###

First you need to create a mochiweb project. Take a look at mochiweb github [https://github.com/mochi/mochiweb](https://github.com/mochi/mochiweb)

### Add mochirest dependency ###

Once you created your initial project, you need to add mochirest as a dependency inside rebar.config file.

```erlang 
%% -*- erlang -*-
{erl_opts, [debug_info]}.
{deps, [
  {mochiweb, ".*", {git, "git://github.com/mochi/mochiweb.git", {branch, "master"}}},
  {mochirest, ".*", {git, "git://github.com/jdanifh/mochirest", {branch, "master"}}}
]}.
{cover_enabled, true}.
{eunit_opts, [verbose, {report,{eunit_surefire,[{dir,"."}]}}]}.
```

### Use mochirest router ###

To use mochirest router you only need to get the handlers and set all the router options.

```erlang
Handlers = mochirest:handlers(),
RouterOpt = [{docroot, DocRoot}, {handlers, Handlers}],
Loop = fun (Req) ->
    mochirest:router(Req, RouterOpt)
end,
mochiweb_http:start([{name, ?MODULE}, {loop, Loop} | Options1]).
```

### Define endpoints and handlers ###

To set an endpoint, just add a module attribute defining the url and the handler function. Like this:

```erlang
-get({"/users/:id", get/2}).

get(Request, Params) ->
	Id = erlang:list_to_integer(proplists:get_value(id, Params)),
	[{id, Id}, {name, <<"Kenan">>}, {surname, <<"Kodro">>}].
```

You can use a handler function on the same module you defined the endpoint or you can use a handler function from another module.

```erlang
-get({"/users/:id", ?MODULE, get/2}).
```

### Router Options ###
The valid options are:

| Option | Type | Description |
|--------|------|-------------|
| docroot | string() | Set the static documents route |
| handlers | [tuple()] | Set the application handlers |
| index | string() | Set an application index file |
| auth | function()  Set an authentication function |

