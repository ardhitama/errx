defmodule ErrxTest do
  use ExUnit.Case
  doctest Errx

  test "wrap correctly" do
    err = Errx.wrap({:error, :failure_code}, "something wrong")

    assert err ==
             {:error,
              %Errx{
                file: "test/errx_test.exs:6",
                func: "Elixir.ErrxTest.test wrap correctly/1",
                error: :failure_code,
                context: "something wrong"
              }}

    err = Errx.wrap(:failure_code)

    assert err ==
             {:error,
              %Errx{
                file: "test/errx_test.exs:17",
                func: "Elixir.ErrxTest.test wrap correctly/1",
                error: :failure_code,
                context: nil
              }}

    {:error, %{error: reason}} = err
    assert reason == :failure_code

    err = {:error, :first} |> Errx.wrap(:details) |> Errx.wrap()

    assert err ==
             {:error,
              %Errx{
                context: :details,
                file: "test/errx_test.exs:31",
                func: "Elixir.ErrxTest.test wrap correctly/1",
                error: :first
              }}

    err = {:error, :first} |> Errx.wrap() |> Errx.wrap(:details)

    assert err ==
             {:error,
              %Errx{
                context: :details,
                file: "test/errx_test.exs:42",
                func: "Elixir.ErrxTest.test wrap correctly/1",
                error: %Errx{
                  context: nil,
                  file: "test/errx_test.exs:42",
                  func: "Elixir.ErrxTest.test wrap correctly/1",
                  error: :first
                }
              }}

    err = {:error, :first} |> Errx.wrap() |> Errx.wrap()

    assert err ==
             {:error,
              %Errx{
                context: nil,
                file: "test/errx_test.exs:58",
                func: "Elixir.ErrxTest.test wrap correctly/1",
                error: :first
              }}
  end

  test "get original reason correctly" do
    err = Errx.wrap({:error, :failure_code}, "something wrong")
    assert Errx.unwrap(err) == {:error, :failure_code}

    err = {:error, :failure_code}
    assert Errx.unwrap(err) == {:error, :failure_code}

    err = {:foo, :bar}
    assert Errx.unwrap(err) == {:foo, :bar}

    err = {:error, :first} |> Errx.wrap() |> Errx.wrap()
    assert Errx.unwrap(err) == {:error, :first}

    err = {:error, :first} |> Errx.wrap(:details) |> Errx.wrap()
    assert Errx.unwrap(err) == {:error, :first}

    err = {:error, :first} |> Errx.wrap() |> Errx.wrap(:details)
    assert Errx.unwrap(err) == {:error, :first}
  end
end
