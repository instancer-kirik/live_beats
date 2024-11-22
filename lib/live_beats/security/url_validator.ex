defmodule LiveBeats.Security.UrlValidator do
  @moduledoc """
  Provides URL validation and sanitization for secure redirects and authentication flows.
  Checks for:
  - Hidden/control characters
  - URL encoding attacks
  - Protocol safety
  - Domain validation
  - Path traversal attempts
  - Unicode normalization issues
  """

  @type validation_error ::
    :invalid_format |
    :invalid_protocol |
    :invalid_domain |
    :invalid_characters |
    :path_traversal |
    :unicode_attack |
    :double_encoding |
    :invalid_port |
    :blacklisted_ip |
    :localhost_forbidden

  @type validation_result :: {:ok, String.t()} | {:error, validation_error()}

  # Allowed protocols for external URLs
  @allowed_protocols ["https", "http"]

  # Characters that should never appear in URLs
  @forbidden_chars [
    0x00..0x1F,           # Control characters
    0x7F..0x9F,           # Extended control characters
    0x2028..0x2029,       # Line/paragraph separators
    [0xFEFF],             # Byte order mark
    0xFFF0..0xFFFF        # Specials
  ]
  |> Enum.flat_map(fn
    first..last -> Enum.to_list(first..last)
    list when is_list(list) -> list
  end)
  |> List.to_string()

  # Regex for basic URL format validation
  @url_regex ~r/^(?<protocol>https?):\/\/(?<domain>[^\s\/?#]+)(?<path>\/[^\s]*)?$/

  @doc """
  Validates and sanitizes a URL for secure use in authentication flows.
  Returns {:ok, sanitized_url} if valid, {:error, reason} if invalid.

  ## Examples

      iex> UrlValidator.validate_auth_url("https://example.com/callback")
      {:ok, "https://example.com/callback"}

      iex> UrlValidator.validate_auth_url("javascript:alert(1)")
      {:error, :invalid_protocol}
  """
  @spec validate_auth_url(String.t()) :: validation_result()
  def validate_auth_url(url) when is_binary(url) do
    with {:ok, url} <- check_basic_format(url),
         {:ok, url} <- check_forbidden_characters(url),
         {:ok, url} <- check_encoding_attacks(url),
         {:ok, parts} <- extract_url_parts(url),
         :ok <- validate_protocol(parts.protocol),
         :ok <- validate_domain(parts.domain),
         :ok <- validate_path(parts.path),
         {:ok, url} <- normalize_url(url) do
      {:ok, url}
    end
  end

  def validate_auth_url(_), do: {:error, :invalid_format}

  @doc """
  Validates a URL specifically for internal redirects within the application.
  More restrictive than validate_auth_url/1.

  ## Examples

      iex> UrlValidator.validate_internal_redirect("/dashboard")
      {:ok, "/dashboard"}

      iex> UrlValidator.validate_internal_redirect("https://external.com")
      {:error, :invalid_domain}
  """
  @spec validate_internal_redirect(String.t()) :: validation_result()
  def validate_internal_redirect(path) when is_binary(path) do
    if String.starts_with?(path, "/") and not String.contains?(path, "://") do
      with {:ok, path} <- check_forbidden_characters(path),
           {:ok, path} <- check_encoding_attacks(path),
           :ok <- validate_path(path),
           {:ok, path} <- normalize_path(path) do
        {:ok, path}
      end
    else
      {:error, :invalid_format}
    end
  end

  def validate_internal_redirect(_), do: {:error, :invalid_format}

  # Private functions

  defp check_basic_format(url) do
    if String.match?(url, @url_regex) do
      {:ok, url}
    else
      {:error, :invalid_format}
    end
  end

  defp check_forbidden_characters(url) do
    if String.contains?(url, @forbidden_chars) do
      {:error, :invalid_characters}
    else
      {:ok, url}
    end
  end

  defp check_encoding_attacks(url) do
    decoded = URI.decode(url)
    double_decoded = URI.decode(decoded)

    cond do
      decoded != double_decoded ->
        {:error, :double_encoding}

      String.contains?(decoded, "%") ->
        check_remaining_percent(decoded)

      true ->
        {:ok, url}
    end
  end

  defp check_remaining_percent(decoded) do
    # Check if any remaining % are part of valid hex sequences
    case Regex.scan(~r/%(?![0-9A-Fa-f]{2})/, decoded) do
      [] -> {:ok, decoded}
      _matches -> {:error, :invalid_characters}
    end
  end

  defp extract_url_parts(url) do
    case Regex.named_captures(@url_regex, url) do
      %{"protocol" => protocol, "domain" => domain, "path" => path} ->
        {:ok, %{protocol: protocol, domain: domain, path: path || "/"}}
      _ ->
        {:error, :invalid_format}
    end
  end

  defp validate_protocol(protocol) do
    if protocol in @allowed_protocols do
      :ok
    else
      {:error, :invalid_protocol}
    end
  end

  defp validate_domain(domain) do
    cond do
      String.contains?(domain, ["localhost", "127.0.0.1", "::1"]) ->
        {:error, :localhost_forbidden}

      is_ip_address?(domain) ->
        {:error, :blacklisted_ip}

      contains_port?(domain) ->
        validate_domain_with_port(domain)

      true ->
        validate_domain_format(domain)
    end
  end

  defp is_ip_address?(domain) do
    case :inet.parse_address(to_charlist(domain)) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp contains_port?(domain) do
    String.contains?(domain, ":")
  end

  defp validate_domain_with_port(domain) do
    case String.split(domain, ":") do
      [domain_part, port_str] ->
        with :ok <- validate_domain_format(domain_part),
             {port, ""} <- Integer.parse(port_str),
             true <- port >= 1 and port <= 65535 do
          :ok
        else
          _ -> {:error, :invalid_port}
        end
      _ ->
        {:error, :invalid_format}
    end
  end

  defp validate_domain_format(domain) do
    # Basic domain format validation
    # You might want to make this more strict based on your needs
    if String.match?(domain, ~r/^[a-zA-Z0-9][a-zA-Z0-9\-\.]*[a-zA-Z0-9]$/) do
      :ok
    else
      {:error, :invalid_domain}
    end
  end

  defp validate_path(nil), do: :ok
  defp validate_path(path) do
    normalized = normalize_path(path)

    cond do
      String.contains?(path, "..") ->
        {:error, :path_traversal}

      String.contains?(path, ["<", ">", "'", "\""]) ->
        {:error, :invalid_characters}

      true ->
        :ok
    end
  end

  defp normalize_url(url) do
    # Normalize the URL using NFKC normalization
    # This helps prevent unicode-based attacks
    try do
      normalized = String.normalize(url, :nfkc)
      {:ok, normalized}
    rescue
      _ -> {:error, :unicode_attack}
    end
  end

  defp normalize_path(path) do
    # Normalize the path component
    path
    |> String.split("/")
    |> Enum.reject(&(&1 in ["", "."]))
    |> Enum.reduce([], fn
      "..", [_ | rest] -> rest
      segment, acc -> [segment | acc]
    end)
    |> Enum.reverse()
    |> Enum.join("/")
    |> then(&("/" <> &1))
  end
end
