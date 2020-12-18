defmodule Errx do
  @type t :: %Errx{}

  defstruct [:file, :func, :reason, :parent]

  @spec wrap({:error, any} | Errx.t()) :: Errx.t()
  def wrap(error) do
    {mod, fname, farity, [file: file, line: line]} =
      Process.info(self(), :current_stacktrace) |> elem(1) |> Enum.fetch!(2)

    func = "#{mod}.#{fname}/#{farity}"
    file = "#{file}:#{line}"

    case error do
      %Errx{} ->
        error

      {:error, reason} ->
        %Errx{func: func, file: file, reason: reason}

      reason ->
        %Errx{func: func, file: file, reason: reason}
    end
  end

  @spec wrap({:error, any} | Errx.t(), {:error, any} | Errx.t()) :: Errx.t()
  def wrap(parent_error, child_error) do
    %Errx{wrap(child_error) | parent: wrap(parent_error)}
  end

  @spec match(any) :: any
  defmacro match({:error, reason}) do
    quote do
      %Errx{reason: unquote(reason)}
    end
  end

  defmacro match(%Errx{reason: reason}) do
    quote do
      {:error, unquote(reason)}
    end
  end

  defmacro match(any) do
    quote do
      unquote(any)
    end
  end

  @spec match({:error, any} | Errx.t(), {:error, any} | Errx.t()) :: boolean
  def match(%Errx{reason: err1}, {:error, err2}) do
    err1 == err2
  end

  def match({:error, err1}, %Errx{reason: err2}) do
    err1 == err2
  end
end
