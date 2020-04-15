defmodule ErrxTest do
  use ExUnit.Case
  doctest Errx

  test "wrap correctly" do
    assert Errx.wrap({:error, :failure_code}, "something wrong") == %Errx{
             file: "test/errx_test.exs:6",
             func: "Elixir.ErrxTest.test wrap correctly/1",
             error: :failure_code,
             context: "something wrong"
           }

    assert Errx.wrap(:failure_code) == %Errx{
             file: "test/errx_test.exs:13",
             func: "Elixir.ErrxTest.test wrap correctly/1",
             error: :failure_code,
             context: nil
           }

    err = {:error, :first} |> Errx.wrap(:details) |> Errx.wrap()

    assert err == %Errx{
             context: :details,
             file: "test/errx_test.exs:20",
             func: "Elixir.ErrxTest.test wrap correctly/1",
             error: :first
           }

    err = {:error, :first} |> Errx.wrap() |> Errx.wrap(:details)

    assert err == %Errx{
             context: :details,
             file: "test/errx_test.exs:29",
             func: "Elixir.ErrxTest.test wrap correctly/1",
             error: %Errx{
               context: nil,
               file: "test/errx_test.exs:29",
               func: "Elixir.ErrxTest.test wrap correctly/1",
               error: :first
             }
           }

    err = {:error, :first} |> Errx.wrap() |> Errx.wrap()

    assert err == %Errx{
             context: nil,
             file: "test/errx_test.exs:43",
             func: "Elixir.ErrxTest.test wrap correctly/1",
             error: :first
           }
  end

  test "get original reason correctly" do
    err = Errx.wrap({:error, :failure_code}, "something wrong")

    assert Errx.first(err) == %Errx{
             context: "something wrong",
             file: "test/errx_test.exs:54",
             func: "Elixir.ErrxTest.test get original reason correctly/1",
             error: :failure_code
           }

    err = {:error, :failure_code}
    assert Errx.first(err) == {:error, :failure_code}

    err = {:foo, :bar}
    assert Errx.first(err) == {:foo, :bar}

    err = {:error, :first} |> Errx.wrap() |> Errx.wrap()

    assert Errx.first(err) == %Errx{
             context: nil,
             error: :first,
             file: "test/errx_test.exs:69",
             func: "Elixir.ErrxTest.test get original reason correctly/1"
           }

    err = {:error, :first} |> Errx.wrap(:details) |> Errx.wrap()

    assert Errx.first(err) == %Errx{
             context: :details,
             error: :first,
             file: "test/errx_test.exs:78",
             func: "Elixir.ErrxTest.test get original reason correctly/1"
           }

    err = {:error, :first} |> Errx.wrap() |> Errx.wrap(:details)

    assert Errx.first(err) == %Errx{
             context: nil,
             error: :first,
             file: "test/errx_test.exs:87",
             func: "Elixir.ErrxTest.test get original reason correctly/1"
           }

    assert Errx.first(:val) == :val
  end

  test "allows errx to be matched in pattern match" do
    res =
      case {:error, :failure} do
        Errx.match(:failure) ->
          true

        _ ->
          false
      end

    assert res == false

    res =
      case Errx.wrap(:failure) do
        Errx.match(:failure) ->
          true
      end

    assert res == true

    res =
      with {:ok} <- Errx.wrap(:val) do
        false
      else
        Errx.match(:val) ->
          true
      end

    assert res == true
  end
end
