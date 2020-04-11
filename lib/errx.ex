defmodule Errx do
  @derive Jason.Encoder
  defstruct [:file, :func, :error, :context]

  def wrap(error) do
    wrap(error, nil)
  end

  def wrap(error, context) do
    {mod, fname, farity, [file: file, line: line]} =
      Process.info(self(), :current_stacktrace) |> elem(1) |> Enum.fetch!(2)

    func = "#{mod}.#{fname}/#{farity}"
    file = "#{file}:#{line}"

    case error do
      {:error, reason = %Errx{}} when context != nil ->
        {:error, %Errx{func: func, file: file, error: reason, context: context}}

      {:error, %Errx{}} ->
        error

      {:error, reason} ->
        {:error, %Errx{func: func, file: file, error: reason, context: context}}

      _ ->
        {:error, %Errx{func: func, file: file, error: error, context: context}}
    end
  end

  def unwrap(error) do
    case error do
      {:error, %Errx{error: %Errx{} = error}} ->
        unwrap({:error, error})

      {:error, %{error: reason} = %Errx{}} ->
        {:error, reason}

      _ ->
        error
    end
  end
end
