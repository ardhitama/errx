defmodule Errx do
  @derive Jason.Encoder
  defstruct [:file, :func, :reason, :details]

  def new(error, details \\ nil) do
    {mod, fname, farity, [file: file, line: line]} =
      Process.info(self(), :current_stacktrace) |> elem(1) |> Enum.fetch!(2)

    func = "#{mod}.#{fname}/#{farity}"
    file = "#{file}:#{line}"

    case error do
      {:error, reason} ->
        {:error, %Errx{func: func, file: file, reason: reason, details: details}}

      _ ->
        {:error, %Errx{func: func, file: file, reason: error, details: details}}
    end
  end

  def error(error) do
    case error do
      {:error, errx = %Errx{}} ->
        %{reason: reason} = errx
        reason

      {:error, reason} ->
        reason

      _ ->
        error
    end
  end
end
