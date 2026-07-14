defmodule ErrxTest do
  use ExUnit.Case, async: true

  doctest Errx

  describe "wrap/1" do
    test "wraps raw reasons and error tuples" do
      assert {:error, %Errx{reason: :failure, parent: nil} = raw} = Errx.wrap(:failure)
      assert_location(raw, 1)

      assert {:error, %Errx{reason: :failure} = tuple} = Errx.wrap({:error, :failure})
      assert_location(tuple, 1)
    end

    test "preserves existing Errx values" do
      wrapped = Errx.wrap(:failure)
      assert Errx.wrap(wrapped) == wrapped

      {:error, error} = wrapped
      assert Errx.wrap(error) == wrapped
    end

    test "captures the first caller outside Errx" do
      assert {:error, error} = wrap_from_helper()
      assert_receive :wrapped
      assert_location(error, :wrap_from_helper, 0)
    end
  end

  describe "cause chains" do
    test "wrap/2 associates parent and child errors" do
      assert {:error, %Errx{reason: :child, parent: %Errx{reason: :parent}}} =
               Errx.wrap(:parent, :child)
    end

    test "with_parent/2 is the explicit child-first API" do
      assert {:error, %Errx{reason: :child, parent: %Errx{reason: :parent}} = error} =
               Errx.with_parent(:child, :parent)

      assert %Errx{reason: :parent} = Errx.cause(error)
      assert %Errx{reason: :parent} = Errx.cause({:error, error})
    end

    test "preserves an existing cause chain" do
      {:error, child} = Errx.wrap(:existing_parent, :child)

      assert {:error,
              %Errx{
                reason: :child,
                parent: %Errx{
                  reason: :existing_parent,
                  parent: %Errx{reason: :oldest_parent}
                }
              }} = Errx.with_parent(child, :oldest_parent)
    end
  end

  describe "matching" do
    test "supports pattern matching" do
      assert (case Errx.wrap(:failure) do
                Errx.match(:failure) -> true
              end)
    end

    test "compares wrapped and raw reasons" do
      left = Errx.wrap(:failure)
      right = Errx.wrap(:failure)
      different = Errx.wrap(:different)

      assert Errx.match(left, right)
      assert Errx.match(left, {:error, :failure})
      assert Errx.match({:error, :failure}, left)
      assert Errx.match(left, :failure)
      assert Errx.match(:failure, left)
      refute Errx.match(left, different)
    end

    test "returns false for unrelated values" do
      refute Errx.match(:failure, :failure)
      refute Errx.match({:error, :failure}, {:error, :failure})
      refute Errx.match(:failure, :different)
    end
  end

  describe "metadata" do
    test "put_metadata/2 replaces metadata" do
      assert {:error, %Errx{metadata: %{foo: :bar}} = error} =
               Errx.put_metadata(:failure, %{foo: :bar})

      assert Errx.metadata(error) == %{foo: :bar}
      assert Errx.metadata({:error, error}) == %{foo: :bar}
      assert Errx.metadata(:failure) == nil
    end

    test "metadata/2 remains a replacement alias" do
      assert {:error, %Errx{metadata: :replacement}} =
               :failure
               |> Errx.put_metadata(%{foo: :bar})
               |> Errx.metadata(:replacement)
    end

    test "merge_metadata/2 combines maps and overwrites duplicate keys" do
      error = Errx.put_metadata(:failure, %{foo: :old, keep: true})

      assert {:error, %Errx{metadata: %{foo: :new, keep: true, added: true}}} =
               Errx.merge_metadata(error, %{foo: :new, added: true})
    end

    test "merge_metadata/2 rejects existing non-map metadata" do
      error = Errx.put_metadata(:failure, :opaque)

      assert_raise ArgumentError, ~r/cannot merge map metadata/, fn ->
        Errx.merge_metadata(error, %{foo: :bar})
      end
    end
  end

  describe "exceptions" do
    test "raises with default and atom reasons" do
      assert_raise Errx, "errx_exception", fn -> raise Errx end
      assert_raise Errx, "failure", fn -> raise Errx, :failure end
    end

    test "uses binary messages" do
      assert_raise Errx, "failure", fn -> raise Errx, "failure" end
    end

    test "treats non-binary bitstrings as arbitrary data" do
      bitstring = <<1::1>>
      error = Errx.exception(bitstring)

      assert error.reason == :errx_exception
      assert error.metadata == %{data: bitstring}
    end

    test "accepts wrapped errors" do
      assert_raise Errx, "failure", fn -> raise Errx, Errx.wrap(:failure) end
    end

    test "stores arbitrary exception attributes as data" do
      error = Errx.exception(%{status: 500})

      assert error.reason == :errx_exception
      assert error.metadata == %{data: %{status: 500}}
      assert Errx.message(error) == "errx_exception"
    end

    test "delegates tuple messages" do
      error = Errx.exception("failure")
      assert Errx.message({:error, error}) == "failure"
    end
  end

  defp wrap_from_helper do
    result = Errx.wrap(:failure)
    send(self(), :wrapped)
    result
  end

  defp assert_location(error, arity), do: assert_location(error, nil, arity)

  defp assert_location(
         %Errx{
           location: %{
             module: __MODULE__,
             function: actual_function,
             arity: arity,
             file: location_file,
             line: line
           },
           file: legacy_file,
           func: legacy_function
         },
         function,
         arity
       ) do
    if function != nil do
      assert actual_function == function
    end

    assert is_atom(actual_function)
    assert is_binary(location_file)
    assert String.ends_with?(location_file, "test/errx_test.exs")
    assert is_integer(line) and line > 0
    assert legacy_file == "#{location_file}:#{line}"
    assert legacy_function == "#{__MODULE__}.#{actual_function}/#{arity}"
  end
end
