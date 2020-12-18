defmodule ErrxTest do
  use ExUnit.Case
  doctest Errx

  test "wrap correctly" do
    err = Errx.wrap(:failure_code)

    assert err == %Errx{
             file: "test/errx_test.exs:6",
             func: "Elixir.ErrxTest.test wrap correctly/1",
             reason: :failure_code
           }

    err = Errx.wrap({:error, :failure_code})

    assert err == %Errx{
             file: "test/errx_test.exs:14",
             func: "Elixir.ErrxTest.test wrap correctly/1",
             reason: :failure_code
           }

    assert Errx.wrap(err) == %Errx{
             file: "test/errx_test.exs:14",
             func: "Elixir.ErrxTest.test wrap correctly/1",
             reason: :failure_code
           }

    assert Errx.wrap(%Errx{err | reason: :parent_failure}, err) == %Errx{
             file: "test/errx_test.exs:14",
             func: "Elixir.ErrxTest.test wrap correctly/1",
             reason: :failure_code,
             parent: %Errx{
               file: "test/errx_test.exs:14",
               func: "Elixir.ErrxTest.test wrap correctly/1",
               parent: nil,
               reason: :parent_failure
             }
           }
  end

  test "allows errx to be matched in pattern matching" do
    assert (case(Errx.wrap(:failure)) do
              Errx.match(:failure) ->
                true
            end)
  end

  test "allows errx to be matched in exunit assertion" do
    err = Errx.wrap({:error, :failure})

    assert Errx.match(err, {:error, :failure})
    assert Errx.match({:error, :failure}, err)

    assert Errx.match(err, :failure)
    assert Errx.match(:failure, err)
  end
end
