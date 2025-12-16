defmodule LiveStyleViewTransitionsTest do
  use ExUnit.Case, async: false

  setup do
    LiveStyle.clear()
    :ok
  end

  describe "view_transition/2 macro" do
    test "generates basic view transition CSS" do
      defmodule TestBasicViewTransition do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        view_transition("todo-*", %{
          old: %{
            animation: "250ms ease-out both fade_out"
          },
          new: %{
            animation: "250ms ease-out both fade_in"
          }
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "::view-transition-old(todo-*)"
      assert css =~ "::view-transition-new(todo-*)"
      assert css =~ "animation: 250ms ease-out both fade_out;"
      assert css =~ "animation: 250ms ease-out both fade_in;"
    end

    test "handles :only-child pseudo-class with atom keys" do
      defmodule TestOnlyChild do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        view_transition("card-*", %{
          old_only_child: %{
            animation: "300ms ease-out both scale_out"
          },
          new_only_child: %{
            animation: "300ms ease-out both scale_in"
          }
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "::view-transition-old(card-*):only-child"
      assert css =~ "::view-transition-new(card-*):only-child"
    end

    test "supports media query conditions" do
      defmodule TestMediaQuery do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        view_transition("item-*", %{
          old: %{
            animation: %{
              :default => "250ms ease-out both fade_out",
              "@media (prefers-reduced-motion: reduce)" => "none"
            }
          }
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "::view-transition-old(item-*)"
      assert css =~ "animation: 250ms ease-out both fade_out;"
      assert css =~ "@media (prefers-reduced-motion: reduce)"
      assert css =~ "animation: none;"
    end

    test "supports multiple properties per pseudo-element" do
      defmodule TestMultipleProps do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        view_transition("box-*", %{
          old: %{
            animation: "200ms ease-out both fade_out",
            opacity: "0.5",
            transform: "scale(0.9)"
          }
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "animation: 200ms ease-out both fade_out;"
      assert css =~ "opacity: 0.5;"
      assert css =~ "transform: scale(0.9);"
    end

    test "supports view-transition-group and view-transition-image-pair" do
      defmodule TestAllPseudoElements do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        view_transition("slide-*", %{
          group: %{
            animation_duration: "300ms"
          },
          image_pair: %{
            isolation: "isolate"
          }
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "::view-transition-group(slide-*)"
      assert css =~ "animation-duration: 300ms;"
      assert css =~ "::view-transition-image-pair(slide-*)"
      assert css =~ "isolation: isolate;"
    end

    test "converts underscores to hyphens in property names" do
      defmodule TestPropertyNames do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        view_transition("test-*", %{
          old: %{
            animation_duration: "200ms",
            animation_timing_function: "ease-out",
            animation_fill_mode: "both"
          }
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "animation-duration: 200ms;"
      assert css =~ "animation-timing-function: ease-out;"
      assert css =~ "animation-fill-mode: both;"
    end

    test "supports exact transition names (no wildcard)" do
      defmodule TestExactName do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        view_transition("header", %{
          old: %{
            animation: "300ms ease-out both slide_out"
          }
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "::view-transition-old(header)"
    end

    test "multiple view_transition calls accumulate" do
      defmodule TestMultipleTransitions do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        view_transition("card-*", %{
          old: %{
            animation: "200ms ease-out both fade_out"
          }
        })

        view_transition("list-*", %{
          new: %{
            animation: "300ms ease-in both slide_in"
          }
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "::view-transition-old(card-*)"
      assert css =~ "::view-transition-new(list-*)"
    end

    test "handles string default key in conditions" do
      defmodule TestStringDefault do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        view_transition("modal-*", %{
          old: %{
            animation: %{
              "default" => "250ms ease-out both fade_out",
              "@media (prefers-reduced-motion: reduce)" => "none"
            }
          }
        })
      end

      css = LiveStyle.get_all_css()

      assert css =~ "animation: 250ms ease-out both fade_out;"
      assert css =~ "@media (prefers-reduced-motion: reduce)"
    end

    test "resolves keyframe atom references to hashed names" do
      defmodule TestKeyframeResolution do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        defkeyframes(:my_fade_out, %{
          from: %{opacity: "1"},
          to: %{opacity: "0"}
        })

        defkeyframes(:my_fade_in, %{
          from: %{opacity: "0"},
          to: %{opacity: "1"}
        })

        view_transition("animated-*", %{
          old: %{
            animation_name: :my_fade_out,
            animation_duration: "200ms"
          },
          new: %{
            animation_name: :my_fade_in,
            animation_duration: "200ms"
          }
        })
      end

      css = LiveStyle.get_all_css()

      # Should contain hashed keyframe names, not raw atom names
      refute css =~ "animation-name: my_fade_out"
      refute css =~ "animation-name: my_fade_in"
      assert css =~ ~r/animation-name: k[a-f0-9]+;/
    end

    test "keyframe resolution works with conditional values" do
      defmodule TestKeyframeConditional do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        defkeyframes(:cond_fade, %{
          from: %{opacity: "1"},
          to: %{opacity: "0"}
        })

        view_transition("cond-*", %{
          old: %{
            animation_name: %{
              :default => :cond_fade,
              "@media (prefers-reduced-motion: reduce)" => "none"
            }
          }
        })
      end

      css = LiveStyle.get_all_css()

      # Should have hashed name in default, "none" in media query
      assert css =~ ~r/animation-name: k[a-f0-9]+;/
      assert css =~ "animation-name: none;"
    end
  end

  describe "generate_name_css/2" do
    test "generates correct CSS structure" do
      css =
        LiveStyle.ViewTransitions.generate_name_css("test-*", %{
          old: %{
            animation: "200ms ease-out both fade"
          }
        })

      assert css =~ "::view-transition-old(test-*) {"
      assert css =~ "animation: 200ms ease-out both fade;"
      assert css =~ "}"
    end

    test "handles empty declarations gracefully" do
      css =
        LiveStyle.ViewTransitions.generate_name_css("test-*", %{
          old: %{}
        })

      # Should not crash, may produce empty or minimal output
      assert is_binary(css)
    end
  end

  describe "resolve_keyframes/2" do
    test "resolves atom values in nested maps" do
      keyframes_map = %{fade_in: "k123", fade_out: "k456"}

      input = %{
        old: %{
          animation_name: :fade_out
        },
        new: %{
          animation_name: :fade_in
        }
      }

      result = LiveStyle.ViewTransitions.resolve_keyframes(input, keyframes_map)

      assert result == %{
               old: %{animation_name: "k456"},
               new: %{animation_name: "k123"}
             }
    end

    test "resolves atoms in conditional maps" do
      keyframes_map = %{fade_out: "k789"}

      input = %{
        old: %{
          animation_name: %{
            :default => :fade_out,
            "@media test" => "none"
          }
        }
      }

      result = LiveStyle.ViewTransitions.resolve_keyframes(input, keyframes_map)

      assert result == %{
               old: %{
                 animation_name: %{
                   :default => "k789",
                   "@media test" => "none"
                 }
               }
             }
    end

    test "leaves unknown atoms unchanged" do
      keyframes_map = %{known: "k111"}

      input = %{old: %{animation_name: :unknown}}

      result = LiveStyle.ViewTransitions.resolve_keyframes(input, keyframes_map)

      assert result == %{old: %{animation_name: :unknown}}
    end
  end

  describe "keyframe validation" do
    test "raises compile error for undefined keyframe reference" do
      assert_raise CompileError, ~r/Undefined keyframe reference.*:nonexistent_keyframe/, fn ->
        defmodule TestUndefinedKeyframe do
          use LiveStyle.Tokens
          use LiveStyle.ViewTransitions

          view_transition("test-*", %{
            old: %{
              animation_name: :nonexistent_keyframe
            }
          })
        end
      end
    end

    test "raises compile error for undefined keyframe in conditional" do
      assert_raise CompileError, ~r/Undefined keyframe reference.*:missing_fade/, fn ->
        defmodule TestUndefinedConditionalKeyframe do
          use LiveStyle.Tokens
          use LiveStyle.ViewTransitions

          view_transition("test-*", %{
            old: %{
              animation_name: %{
                :default => :missing_fade,
                "@media test" => "none"
              }
            }
          })
        end
      end
    end

    test "allows CSS keyword atoms like :none" do
      defmodule TestCSSKeywords do
        use LiveStyle.Tokens
        use LiveStyle.ViewTransitions

        view_transition("test-*", %{
          old: %{
            animation_name: %{
              :default => "some-animation",
              "@media (prefers-reduced-motion: reduce)" => :none
            }
          }
        })
      end

      css = LiveStyle.get_all_css()
      assert css =~ "animation-name: none;"
    end

    test "shows defined keyframes in error message" do
      error =
        assert_raise CompileError, fn ->
          defmodule TestShowsDefinedKeyframes do
            use LiveStyle.Tokens
            use LiveStyle.ViewTransitions

            defkeyframes(:existing_fade, %{
              from: %{opacity: "1"},
              to: %{opacity: "0"}
            })

            view_transition("test-*", %{
              old: %{
                animation_name: :wrong_name
              }
            })
          end
        end

      assert error.description =~ "Defined keyframes: :existing_fade"
      assert error.description =~ ":wrong_name"
    end

    test "validates multiple undefined references" do
      error =
        assert_raise CompileError, fn ->
          defmodule TestMultipleUndefined do
            use LiveStyle.Tokens
            use LiveStyle.ViewTransitions

            view_transition("test-*", %{
              old: %{animation_name: :missing_one},
              new: %{animation_name: :missing_two}
            })
          end
        end

      assert error.description =~ ":missing_one"
      assert error.description =~ ":missing_two"
    end
  end
end
