defmodule Errx do
  @type t :: %Errx{}

  defstruct [:file, :func, :error, :context]

  @spec wrap(any) :: Errx.t()
  def wrap(error) do
    wrap(error, nil)
  end

  @spec wrap(any, any) :: Errx.t()
  def wrap(error, context) do
    {mod, fname, farity, [file: file, line: line]} =
      Process.info(self(), :current_stacktrace) |> elem(1) |> Enum.fetch!(2)

    func = "#{mod}.#{fname}/#{farity}"
    file = "#{file}:#{line}"

    case error do
      %Errx{} when context != nil ->
        %Errx{func: func, file: file, error: error, context: context}

      %Errx{} ->
        error

      {:error, reason} ->
        %Errx{func: func, file: file, error: reason, context: context}

      _ ->
        %Errx{func: func, file: file, error: error, context: context}
    end
  end

  @spec first(any) :: Errx.t()
  def first(error) do
    case error do
      %Errx{error: %Errx{} = error} ->
        first(error)

      _ ->
        wrap(error)
    end
  end

  defmacro match(error_value) do
    quote do
      %Errx{error: unquote(error_value)}
    end
  end


  @spec match(any, any) :: boolean
  def match(%Errx{error: err1}, {:error, err2}) do
    err1 == err2
  end

  def match({:error, err1}, %Errx{error: err2}) do
    err1 == err2
  end

  def match(err1, %Errx{error: err2}) do
    err1 == err2
  end

  def match(%Errx{error: err1}, err2) do
    err1 == err2
  end
end
