defmodule Errx do
  @moduledoc """
  Adds call-site context, metadata, and cause chains to conventional
  `{:error, reason}` values.

  The public constructors return `{:error, %Errx{}}`, so wrapped failures
  remain compatible with standard Elixir tuple-based error handling.

  ## Wrapping

      iex> {:error, error} = Errx.wrap(:not_found)
      iex> error.reason
      :not_found
      iex> is_map(error.location)
      true

  Existing wrapped errors are returned unchanged:

      iex> wrapped = Errx.wrap(:not_found)
      iex> Errx.wrap(wrapped) == wrapped
      true

  ## Matching

      iex> Errx.match(Errx.wrap(:not_found), {:error, :not_found})
      true
      iex> Errx.match(:not_found, :not_found)
      false

  ## Metadata and causes

      iex> {:error, error} = Errx.put_metadata(:not_found, %{resource: "user"})
      iex> error.metadata
      %{resource: "user"}

      iex> {:error, error} = Errx.wrap(:database_unavailable, :lookup_failed)
      iex> {error.reason, error.parent.reason}
      {:lookup_failed, :database_unavailable}
  """

  @typedoc "Structured information about the first caller outside `Errx`."
  @type location :: %{
          module: module(),
          function: atom(),
          arity: non_neg_integer(),
          file: String.t() | nil,
          line: pos_integer() | nil
        }

  @typedoc "A contextual error value."
  @type t :: %__MODULE__{
          file: String.t() | nil,
          func: String.t() | nil,
          location: location() | nil,
          reason: term(),
          metadata: term(),
          parent: t() | nil
        }

  defexception [:file, :func, :location, :reason, :metadata, :parent]

  @doc """
  Wraps a reason or `{:error, reason}` value with caller information.

  Passing an existing `%Errx{}` or `{:error, %Errx{}}` preserves the existing
  value and its original location.
  """
  @spec wrap(term()) :: {:error, t()}
  def wrap(error) do
    {:error, wrap_with_location(error, caller_location())}
  end

  @doc """
  Wraps a child error and associates a parent cause with it.

  Existing cause chains on the child are preserved. The new parent is appended
  to the end of the chain rather than replacing an existing parent.
  """
  @spec wrap(term(), term()) :: {:error, t()}
  def wrap(parent_error, child_error) do
    with_parent(child_error, parent_error)
  end

  @doc """
  Associates `parent_error` with `error` while preserving any existing chain.

  This is the explicit, child-first equivalent of `wrap(parent, child)`.
  """
  @spec with_parent(term(), term()) :: {:error, t()}
  def with_parent(error, parent_error) do
    location = caller_location()
    child = wrap_with_location(error, location)
    parent = wrap_with_location(parent_error, location)

    {:error, append_parent(child, parent)}
  end

  @doc """
  Replaces metadata on an error.

  This function preserves the historical behavior of `metadata/2` while making
  replacement semantics explicit.
  """
  @spec put_metadata(term(), term()) :: {:error, t()}
  def put_metadata(error, metadata) do
    {:error, %__MODULE__{wrap_with_location(error, caller_location()) | metadata: metadata}}
  end

  @doc """
  Merges map metadata into existing map metadata.

  Existing keys are overwritten by values from `metadata`. An error with `nil`
  metadata is treated as having an empty map. Existing non-map metadata raises
  `ArgumentError` rather than being silently discarded.
  """
  @spec merge_metadata(term(), map()) :: {:error, t()}
  def merge_metadata(error, metadata) when is_map(metadata) do
    wrapped = wrap_with_location(error, caller_location())

    merged =
      case wrapped.metadata do
        nil -> metadata
        current when is_map(current) -> Map.merge(current, metadata)
        current -> raise ArgumentError, "cannot merge map metadata into #{inspect(current)}"
      end

    {:error, %__MODULE__{wrapped | metadata: merged}}
  end

  @doc """
  Replaces metadata on an error.

  Kept for backwards compatibility. Prefer `put_metadata/2` when writing new
  code because its name makes replacement behavior clear.
  """
  @spec metadata(term(), term()) :: {:error, t()}
  def metadata(error, metadata), do: put_metadata(error, metadata)

  @doc "Returns metadata from a wrapped or bare `Errx`, or `nil` otherwise."
  @spec metadata(term()) :: term() | nil
  def metadata(error) do
    case unwrap_errx(error) do
      {:ok, %__MODULE__{metadata: metadata}} -> metadata
      :error -> nil
    end
  end

  @doc "Returns the parent cause from a wrapped or bare `Errx`, or `nil`."
  @spec cause(term()) :: t() | nil
  def cause(error) do
    case unwrap_errx(error) do
      {:ok, %__MODULE__{parent: parent}} -> parent
      :error -> nil
    end
  end

  @doc """
  Produces a pattern for matching an `Errx` reason in `case`, `with`, or
  function clauses.

      case Errx.wrap(:not_found) do
        Errx.match(:not_found) -> :matched
      end
  """
  defmacro match(reason) do
    quote do
      {:error, %Errx{reason: unquote(reason)}}
    end
  end

  @doc """
  Compares error reasons when at least one argument is an `Errx` value.

  Returns `false` for unrelated values instead of raising a
  `FunctionClauseError`.
  """
  @spec match(term(), term()) :: boolean()
  def match(left, right) do
    case {comparable_reason(left), comparable_reason(right)} do
      {{:errx, left_reason}, {:errx, right_reason}} -> left_reason == right_reason
      {{:errx, left_reason}, {:raw, right_reason}} -> left_reason == right_reason
      {{:raw, left_reason}, {:errx, right_reason}} -> left_reason == right_reason
      _ -> false
    end
  end

  @impl true
  def exception(attributes) when is_atom(attributes) do
    wrap_with_location(attributes, caller_location())
  end

  def exception(attributes) when is_binary(attributes) do
    new(:errx_exception, caller_location(), %{message: attributes})
  end

  def exception(%__MODULE__{} = attributes), do: attributes
  def exception({:error, %__MODULE__{} = attributes}), do: attributes

  def exception(attributes) do
    new(:errx_exception, caller_location(), %{data: attributes})
  end

  @impl true
  def message({:error, %__MODULE__{} = error}), do: message(error)

  def message(%__MODULE__{} = error) do
    case error do
      %__MODULE__{metadata: %{message: message}} when is_binary(message) ->
        message

      %__MODULE__{reason: reason} when is_atom(reason) ->
        Atom.to_string(reason)

      %__MODULE__{reason: reason} ->
        inspect(reason)
    end
  end

  defp wrap_with_location(%__MODULE__{} = error, _location), do: error
  defp wrap_with_location({:error, %__MODULE__{} = error}, _location), do: error
  defp wrap_with_location({:error, reason}, location), do: new(reason, location)
  defp wrap_with_location(reason, location), do: new(reason, location)

  defp new(reason, location, metadata \\ nil) do
    %__MODULE__{
      reason: reason,
      metadata: metadata,
      location: location,
      file: legacy_file(location),
      func: legacy_function(location)
    }
  end

  defp append_parent(%__MODULE__{parent: nil} = error, parent) do
    %__MODULE__{error | parent: parent}
  end

  defp append_parent(%__MODULE__{parent: existing} = error, parent) do
    %__MODULE__{error | parent: append_parent(existing, parent)}
  end

  defp unwrap_errx({:error, %__MODULE__{} = error}), do: {:ok, error}
  defp unwrap_errx(%__MODULE__{} = error), do: {:ok, error}
  defp unwrap_errx(_error), do: :error

  defp comparable_reason({:error, %__MODULE__{reason: reason}}), do: {:errx, reason}
  defp comparable_reason(%__MODULE__{reason: reason}), do: {:errx, reason}
  defp comparable_reason({:error, reason}), do: {:raw, reason}
  defp comparable_reason(reason), do: {:raw, reason}

  defp caller_location do
    case Process.info(self(), :current_stacktrace) do
      {:current_stacktrace, stacktrace} -> Enum.find_value(stacktrace, &external_location/1)
      _ -> nil
    end
  end

  defp external_location({module, function, arity_or_arguments, details}) do
    if module in [__MODULE__, Process] do
      nil
    else
      details = if is_list(details), do: details, else: []

      %{
        module: module,
        function: function,
        arity: arity(arity_or_arguments),
        file: details |> Keyword.get(:file) |> normalize_file(),
        line: Keyword.get(details, :line)
      }
    end
  end

  defp external_location(_entry), do: nil

  defp arity(value) when is_integer(value), do: value
  defp arity(arguments) when is_list(arguments), do: length(arguments)
  defp arity(_value), do: 0

  defp normalize_file(nil), do: nil
  defp normalize_file(file) when is_binary(file), do: file
  defp normalize_file(file) when is_list(file), do: List.to_string(file)
  defp normalize_file(file), do: to_string(file)

  defp legacy_file(nil), do: nil
  defp legacy_file(%{file: nil}), do: nil
  defp legacy_file(%{file: file, line: nil}), do: file
  defp legacy_file(%{file: file, line: line}), do: "#{file}:#{line}"

  defp legacy_function(nil), do: nil

  defp legacy_function(%{module: module, function: function, arity: arity}) do
    "#{module}.#{function}/#{arity}"
  end
end
