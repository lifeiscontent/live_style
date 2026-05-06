defmodule LiveStyle.PropertyValidationTest do
  use ExUnit.Case, async: true

  alias LiveStyle.Class.Processor

  describe "conditional property validation" do
    test "raises for unknown conditional property when configured as error" do
      assert_raise CompileError, ~r/Unknown CSS property 'opactiy'/, fn ->
        Processor.Conditional.transform(
          [opactiy: [default: "1", ":hover": "0.5"]],
          level: :error,
          file: "test.ex",
          line: 1
        )
      end
    end

    test "raises for unknown pseudo-element property when configured as error" do
      assert_raise CompileError, ~r/Unknown CSS property 'opactiy'/, fn ->
        Processor.PseudoElement.transform(
          ["::before": [opactiy: "1"]],
          level: :error,
          file: "test.ex",
          line: 1
        )
      end
    end
  end
end
