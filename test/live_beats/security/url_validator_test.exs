defmodule LiveBeats.Security.UrlValidatorTest do
  use ExUnit.Case, async: true
  alias LiveBeats.Security.UrlValidator

  describe "validate_auth_url/1" do
    test "accepts valid https URLs" do
      assert {:ok, _} = UrlValidator.validate_auth_url("https://example.com/callback")
      assert {:ok, _} = UrlValidator.validate_auth_url("https://sub.example.com/path")
      assert {:ok, _} = UrlValidator.validate_auth_url("https://example.com:443/path")
    end

    test "accepts valid http URLs in development" do
      assert {:ok, _} = UrlValidator.validate_auth_url("http://example.com/callback")
    end

    test "rejects invalid protocols" do
      assert {:error, :invalid_protocol} = UrlValidator.validate_auth_url("javascript:alert(1)")
      assert {:error, :invalid_protocol} = UrlValidator.validate_auth_url("data:text/plain")
      assert {:error, :invalid_protocol} = UrlValidator.validate_auth_url("file:///etc/passwd")
    end

    test "rejects URLs with forbidden characters" do
      assert {:error, :invalid_characters} = UrlValidator.validate_auth_url("https://example.com/\0")
      assert {:error, :invalid_characters} = UrlValidator.validate_auth_url("https://example.com/\n")
      assert {:error, :invalid_characters} = UrlValidator.validate_auth_url("https://example.com/\u2028")
    end

    test "rejects double-encoded URLs" do
      assert {:error, :double_encoding} = 
        UrlValidator.validate_auth_url("https://example.com/%252e%252e/")
    end

    test "rejects invalid ports" do
      assert {:error, :invalid_port} = UrlValidator.validate_auth_url("https://example.com:0/path")
      assert {:error, :invalid_port} = UrlValidator.validate_auth_url("https://example.com:65536/path")
      assert {:error, :invalid_port} = UrlValidator.validate_auth_url("https://example.com:abc/path")
    end

    test "rejects localhost and private IPs" do
      assert {:error, :localhost_forbidden} = UrlValidator.validate_auth_url("https://localhost/callback")
      assert {:error, :localhost_forbidden} = UrlValidator.validate_auth_url("https://127.0.0.1/callback")
      assert {:error, :localhost_forbidden} = UrlValidator.validate_auth_url("https://::1/callback")
    end

    test "rejects path traversal attempts" do
      assert {:error, :path_traversal} = UrlValidator.validate_auth_url("https://example.com/../secret")
      assert {:error, :path_traversal} = UrlValidator.validate_auth_url("https://example.com/path/../../")
    end

    test "rejects URLs with invalid characters in path" do
      assert {:error, :invalid_characters} = UrlValidator.validate_auth_url("https://example.com/<script>")
      assert {:error, :invalid_characters} = UrlValidator.validate_auth_url("https://example.com/path'")
      assert {:error, :invalid_characters} = UrlValidator.validate_auth_url("https://example.com/path\"")
    end

    test "handles unicode normalization" do
      valid_url = "https://example.com/café"
      assert {:ok, normalized} = UrlValidator.validate_auth_url(valid_url)
      assert String.normalize(normalized, :nfkc) == normalized
    end
  end

  describe "validate_internal_redirect/1" do
    test "accepts valid internal paths" do
      assert {:ok, "/dashboard"} = UrlValidator.validate_internal_redirect("/dashboard")
      assert {:ok, "/users/123"} = UrlValidator.validate_internal_redirect("/users/123")
      assert {:ok, "/path/to/page"} = UrlValidator.validate_internal_redirect("/path/to/page")
    end

    test "rejects external URLs" do
      assert {:error, :invalid_format} = UrlValidator.validate_internal_redirect("https://example.com")
      assert {:error, :invalid_format} = UrlValidator.validate_internal_redirect("http://example.com")
    end

    test "rejects paths without leading slash" do
      assert {:error, :invalid_format} = UrlValidator.validate_internal_redirect("dashboard")
      assert {:error, :invalid_format} = UrlValidator.validate_internal_redirect("users/123")
    end

    test "rejects path traversal attempts" do
      assert {:error, :path_traversal} = UrlValidator.validate_internal_redirect("/../../etc/passwd")
      assert {:error, :path_traversal} = UrlValidator.validate_internal_redirect("/users/../admin")
    end

    test "rejects paths with forbidden characters" do
      assert {:error, :invalid_characters} = UrlValidator.validate_internal_redirect("/path\0")
      assert {:error, :invalid_characters} = UrlValidator.validate_internal_redirect("/path\n")
      assert {:error, :invalid_characters} = UrlValidator.validate_internal_redirect("/path<script>")
    end

    test "normalizes valid paths" do
      assert {:ok, "/path/to/page"} = UrlValidator.validate_internal_redirect("/path//to///page")
      assert {:ok, "/path/to/page"} = UrlValidator.validate_internal_redirect("/path/./to/./page")
    end
  end

  describe "edge cases" do
    test "handles nil values" do
      assert {:error, :invalid_format} = UrlValidator.validate_auth_url(nil)
      assert {:error, :invalid_format} = UrlValidator.validate_internal_redirect(nil)
    end

    test "handles empty strings" do
      assert {:error, :invalid_format} = UrlValidator.validate_auth_url("")
      assert {:error, :invalid_format} = UrlValidator.validate_internal_redirect("")
    end

    test "handles extremely long URLs" do
      long_path = String.duplicate("a", 2000)
      url = "https://example.com/#{long_path}"
      assert {:ok, _} = UrlValidator.validate_auth_url(url)
    end

    test "handles URLs with query parameters" do
      assert {:ok, _} = UrlValidator.validate_auth_url("https://example.com/path?key=value&other=123")
    end

    test "handles URLs with fragments" do
      assert {:ok, _} = UrlValidator.validate_auth_url("https://example.com/path#section")
    end
  end
end
