defmodule Errx do
  @type t :: %Errx{}

  defexception [:file, :func, :reason, :metadata, :parent]

  defp loc(stack) do
    {mod, fname, farity, [file: file, line: line]} =
      Process.info(self(), :current_stacktrace) |> elem(1) |> Enum.fetch!(stack)

    func = "#{mod}.#{fname}/#{farity}"
    file = "#{file}:#{line}"
    {func, file}
  end

  defp wrap_with_loc(error, stack_skip) do
    {func, file} = loc(stack_skip)

    case error do
      %Errx{} ->
        error

      {:error, %Errx{} = error} ->
        error

      {:error, reason} ->
        %Errx{func: func, file: file, reason: reason}

      reason ->
        %Errx{func: func, file: file, reason: reason}
    end
  end

  @spec wrap(any) :: {:error, Errx.t()}
  def wrap(error) do
    {:error, wrap_with_loc(error, 4)}
  end

  @spec wrap(any, any) :: {:error, Errx.t()}
  def wrap(parent_error, child_error) do
    {:error, %Errx{wrap_with_loc(child_error, 4) | parent: wrap_with_loc(parent_error, 4)}}
  end

  @spec metadata(any, any) :: {:error, Errx.t()}
  def metadata(error, metadata) do
    {:error, %Errx{wrap_with_loc(error, 4) | metadata: metadata}}
  end

  @spec metadata(any) :: any
  def metadata({:error, error}) do
    case error do
      %Errx{} ->
        error.metadata

      _ ->
        nil
    end
  end

  def metadata(error) do
    case error do
      %Errx{} ->
        error.metadata

      _ ->
        nil
    end
  end

  defmacro match(reason) do
    quote do
      {:error, %Errx{reason: unquote(reason)}}
    end
  end

  @spec match(any, any) :: boolean
  def match({:error, %Errx{reason: err1}}, {:error, err2}) do
    err1 == err2
  end

  def match({:error, err1}, {:error, %Errx{reason: err2}}) do
    err1 == err2
  end

  def match(err1, {:error, %Errx{reason: err2}}) do
    err1 == err2
  end

  def match({:error, %Errx{reason: err1}}, err2) do
    err1 == err2
  end

  @impl true
  def exception(attributes) when is_atom(attributes) do
    wrap_with_loc(attributes, 3)
  end

  @impl true
  def exception(attributes) when is_bitstring(attributes) do
    %Errx{wrap_with_loc(:errx_exception, 4) | metadata: %{message: attributes}}
  end

  @impl true
  def exception(%Errx{} = attributes) do
    attributes
  end

  @impl true
  def exception({:error, %Errx{} = attributes}) do
    attributes
  end

  @impl true
  def exception(attributes) do
    %Errx{wrap_with_loc(:errx_exception, 4) | metadata: %{data: attributes}}
  end

  @impl true
  def message(%Errx{} = error) do
    case error do
      %Errx{metadata: %{message: reason}} when is_bitstring(reason) ->
        reason

      %Errx{reason: reason} when is_atom(reason) ->
        Atom.to_string(reason)

      %Errx{reason: reason} ->
        inspect(reason)

      _ ->
        inspect(error)
    end
  end

  @impl true
  def message({:error, %Errx{} = error}) do
    case error do
      %Errx{metadata: %{message: reason}} when is_bitstring(reason) ->
        reason

      %Errx{reason: reason} when is_atom(reason) ->
        Atom.to_string(reason)

      %Errx{reason: reason} ->
        inspect(reason)

      _ ->
        inspect(error)
    end
  end
end
