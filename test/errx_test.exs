defmodule ErrxTest do
  use ExUnit.Case
  doctest Errx

  test "wrap correctly" do
    err = Errx.new({:error, :failure_code})

    assert err ==
             {:error,
              %Errx{
                file: "test/errx_test.exs:6",
                func: "Elixir.ErrxTest.test wrap correctly/1",
                reason: :failure_code
              }}

    err = Errx.new(:failure_code)

    assert err ==
             {:error,
              %Errx{
                file: "test/errx_test.exs:16",
                func: "Elixir.ErrxTest.test wrap correctly/1",
                reason: :failure_code
              }}

    {:error, %{reason: reason}} = err
    assert reason == :failure_code
  end

  test "get original reason correctly" do
    err = Errx.new({:error, :failure_code})
    assert Errx.error(err) == :failure_code

    err = {:error, :failure_code}
    assert Errx.error(err) == :failure_code

    err = {:foo, :bar}
    assert Errx.error(err) == {:foo, :bar}
  end
end
