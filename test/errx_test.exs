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

    assert Errx.wrap(:parent_error, :child_error) == %Errx{
             file: "test/errx_test.exs:40",
             func: "Elixir.ErrxTest.test wrap correctly/1",
             reason: :child_error,
             parent: %Errx{
               file: "test/errx_test.exs:40",
               func: "Elixir.ErrxTest.test wrap correctly/1",
               parent: nil,
               reason: :parent_error
             }
           }

    assert Errx.wrap({:error, :parent_error}, :child_error) == %Errx{
             file: "test/errx_test.exs:52",
             func: "Elixir.ErrxTest.test wrap correctly/1",
             reason: :child_error,
             parent: %Errx{
               file: "test/errx_test.exs:52",
               func: "Elixir.ErrxTest.test wrap correctly/1",
               parent: nil,
               reason: :parent_error
             }
           }

    assert Errx.wrap(err, :child_error) == %Errx{
             file: "test/errx_test.exs:64",
             func: "Elixir.ErrxTest.test wrap correctly/1",
             reason: :child_error,
             parent: %Errx{
               file: "test/errx_test.exs:14",
               func: "Elixir.ErrxTest.test wrap correctly/1",
               parent: nil,
               reason: :failure_code
             }
           }

    err1 = Errx.wrap({:error, :failure_code1})
    err2 = Errx.wrap(err1, {:error, :failure_code2})
    err3 = Errx.wrap({:error, :failure_code3})

    assert Errx.wrap(err2, err3) == %Errx{
             file: "test/errx_test.exs:78",
             func: "Elixir.ErrxTest.test wrap correctly/1",
             parent: %Errx{
               file: "test/errx_test.exs:77",
               func: "Elixir.ErrxTest.test wrap correctly/1",
               parent: %Errx{
                 file: "test/errx_test.exs:76",
                 func: "Elixir.ErrxTest.test wrap correctly/1",
                 parent: nil,
                 reason: :failure_code1
               },
               reason: :failure_code2
             },
             reason: :failure_code3
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

  test "metadata enrichment" do
    err = Errx.metadata(:treason, %{foo: :bar})
    assert Errx.match(err, :treason)
    assert Errx.metadata(err) == %{foo: :bar}
  end

  test "raising exception" do
    assert_raise Errx, fn ->
      raise Errx
    end

    assert_raise Errx, "error", fn ->
      raise Errx, "error"
    end

    assert_raise Errx, "failure", fn ->
      raise Errx, Errx.wrap(:failure)
    end

    try do
      raise Errx
    rescue
      err in [Errx] ->
        assert err.reason == :errx_exception
        assert err.file =~ ~r/.+errx_test\.exs:.+/
    end

    try do
      raise Errx, Errx.wrap(:failure)
    rescue
      err in [Errx] ->
        assert err.reason == :failure
        assert err.file =~ ~r/.+errx_test\.exs:.+/
    end

    try do
      raise Errx, :failure
    rescue
      err in [Errx] ->
        assert err.reason == :failure
        assert err.file =~ ~r/.+errx_test\.exs:.+/
    end

    try do
      raise Errx, "failure"
    rescue
      err in [Errx] ->
        assert err.reason == :errx_exception
        assert err.metadata.message == "failure"
        assert err.file =~ ~r/.+errx_test\.exs:.+/
    end
  end
end
