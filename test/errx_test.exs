defmodule ErrxTest do
  use ExUnit.Case
  doctest Errx

  test "wrap correctly" do
    err = Errx.wrap({:error, :failure_code})

    assert err == %Errx{
             file: "test/errx_test.exs:6",
             func: "Elixir.ErrxTest.test wrap correctly/1",
             reason: :failure_code
           }

    assert Errx.wrap(err) == %Errx{
             file: "test/errx_test.exs:6",
             func: "Elixir.ErrxTest.test wrap correctly/1",
             reason: :failure_code
           }
  end

  test "allows errx to be matched in pattern matching" do
    err_tuple = {:error, :failure}
    err = Errx.wrap(err_tuple)

    res =
      case err do
        Errx.match(_err_tuple) ->
          true
      end

    assert res

    res =
      case err do
        %Errx{reason: :failure} ->
          true
      end

    assert res

    res =
      case err do
        Errx.match(_err_tuple) ->
          true
      end

    assert res

    res =
      case err_tuple do
        Errx.match(_err) ->
          true
      end

    assert res
  end

  test "allows errx to be matched in exunit assertion" do
    err = Errx.wrap({:error, :failure})
    assert Errx.match(err, {:error, :failure})
    assert Errx.match({:error, :failure}, err)
  end
end
