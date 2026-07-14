# Errx

Errx enriches conventional Elixir `{:error, reason}` tuples with the caller
location, optional metadata, and a chain of causes. It keeps the tuple shape
used by `case`, `with`, and tagged-return APIs while preserving enough context
to understand where an error was created.

Errx is currently pre-1.0. Minor releases may refine the public API, but
changes are documented and existing tuple-based workflows are kept compatible
where practical.

## Installation

Add `errx` to the dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:errx, "~> 0.5"}
  ]
end
```

Errx 0.5 requires Elixir 1.14 or later.

## Wrap errors

```elixir
{:error, error} = Errx.wrap(:not_found)

error.reason
#=> :not_found

error.location
#=> %{
#=>   module: MyApp.Users,
#=>   function: :fetch,
#=>   arity: 1,
#=>   file: "lib/my_app/users.ex",
#=>   line: 42
#=> }
```

`file` and `func` remain available as formatted compatibility fields. New code
should prefer the structured `location` map.

Both raw reasons and standard error tuples are accepted:

```elixir
Errx.wrap(:not_found)
Errx.wrap({:error, :not_found})
```

Wrapping an existing Errx value is idempotent and preserves its original
location.

## Match reasons

Use `Errx.match/1` in patterns:

```elixir
case Errx.wrap(:not_found) do
  Errx.match(:not_found) -> :recover
end
```

Use `Errx.match/2` in assertions or ordinary expressions:

```elixir
Errx.match(Errx.wrap(:not_found), {:error, :not_found})
#=> true

Errx.match(:not_found, :not_found)
#=> false
```

At least one argument must be an Errx value. Unrelated values return `false`
rather than raising.

## Add metadata

`put_metadata/2` replaces metadata explicitly:

```elixir
error = Errx.put_metadata(:not_found, %{resource: "user", id: 123})
Errx.metadata(error)
#=> %{resource: "user", id: 123}
```

`merge_metadata/2` merges maps and overwrites duplicate keys with the new
values:

```elixir
:failure
|> Errx.put_metadata(%{request_id: "abc", retry: false})
|> Errx.merge_metadata(%{retry: true})
```

The older `metadata/2` function remains as a replacement alias for backwards
compatibility.

## Chain causes

The historical API accepts parent first and child second:

```elixir
{:error, error} = Errx.wrap(:database_unavailable, :lookup_failed)

error.reason
#=> :lookup_failed

error.parent.reason
#=> :database_unavailable
```

`with_parent/2` provides the explicit child-first form:

```elixir
Errx.with_parent(:lookup_failed, :database_unavailable)
```

When the child already has a parent chain, the new parent is appended rather
than replacing existing context. `Errx.cause/1` reads the immediate parent.
The struct field remains named `parent` in 0.x for compatibility; its semantic
meaning is the underlying cause.

## Raise Errx exceptions

```elixir
raise Errx, :not_found
raise Errx, "user was not found"
raise Errx, Errx.wrap(:not_found)
```

Binary attributes become the exception message. Other arbitrary attributes
are stored under `metadata.data`.

## Location limitations

Locations are collected from the current process stack trace. Errx scans for
the first frame outside the Errx and Process modules instead of relying on a
fixed stack index. Generated code, aggressive inlining, or unusual runtime
stack frames may still affect which caller is reported.

## Development

Run the complete local quality suite with:

```shell
mix deps.get
mix quality
```

CI verifies formatting, warnings, tests, Credo, package construction, and a
Dialyzer pass. The matrix covers the oldest supported Elixir release and the
latest stable Elixir/OTP combination.

## License

Errx is licensed under GPL-3.0-only. See `LICENSE`.
