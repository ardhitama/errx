defmodule Errx do
  @type t :: %Errx{}

  defstruct [:file, :func, :reason, :metadata, :parent]

  defp loc(stack) do
    {mod, fname, farity, [file: file, line: line]} =
      Process.info(self(), :current_stacktrace) |> elem(1) |> Enum.fetch!(stack)

    func = "#{mod}.#{fname}/#{farity}"
    file = "#{file}:#{line}"
    {func, file}
  end

  defp wrap(error, func, file) do
    case error do
      %Errx{} ->
        error

      {:error, reason} ->
        %Errx{func: func, file: file, reason: reason}

      reason ->
        %Errx{func: func, file: file, reason: reason}
    end
  end

  @spec wrap(any) :: Errx.t()
  def wrap(error) do
    {func, file} = loc(3)

    wrap(error, func, file)
  end

  @spec wrap(any, any) :: Errx.t()
  def wrap(parent_error, child_error) do
    {func, file} = loc(3)

    %Errx{wrap(child_error, func, file) | parent: wrap(parent_error, func, file)}
  end

  @spec metadata(any, any) :: Errx.t()
  def metadata(error, metadata) do
    %Errx{wrap(error) | metadata: metadata}
  end

  @spec metadata(any) :: any
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
      %Errx{reason: unquote(reason)}
    end
  end

  @spec match(any, any) :: boolean
  def match(%Errx{reason: err1}, {:error, err2}) do
    err1 == err2
  end

  def match({:error, err1}, %Errx{reason: err2}) do
    err1 == err2
  end

  def match(err1, %Errx{reason: err2}) do
    err1 == err2
  end

  def match(%Errx{reason: err1}, err2) do
    err1 == err2
  end
end
