defmodule LiveBeats.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def load_serving do
    {:ok, model_info} = Bumblebee.load_model({:hf, "openai/whisper-tiny"})
    {:ok, featurizer} = Bumblebee.load_featurizer({:hf, "openai/whisper-tiny"})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "openai/whisper-tiny"})

    serving = 
      Nx.Serving.new(
        fn defn_options ->
          # Initialize serving with defn options
          Nx.Defn.default_options(defn_options)

          fn input ->
            # Convert input to mono if needed
            mono_input = 
              case Nx.shape(input) do
                {samples, channels} when channels > 1 ->
                  # Average across channels to get mono
                  Nx.mean(input, axes: [1])
                {_samples} ->
                  input
                shape ->
                  raise ArgumentError, "expected audio tensor of shape {samples} or {samples, channels}, got: #{inspect(shape)}"
              end

            # Apply featurizer to get input features
            features = Bumblebee.apply_featurizer(featurizer, mono_input)

            # Run model prediction
            outputs = 
              Axon.predict(model_info.model, model_info.params, %{
                "input_features" => features
              })

            # Post-process to get text
            Bumblebee.postprocess(outputs, tokenizer)
          end
        end,
        compiler: EXLA,
        batch_size: 1
      )

    serving
  end

  @impl true
  def start(_type, _args) do
    parent = FLAME.Parent.get()
    LiveBeats.MediaLibrary.attach()
    whisper_serving? = parent || FLAME.Backend.impl() != FLAME.FlyBackend

    # Create ETS table for stream chunks
    :ets.new(:stream_chunks, [:named_table, :public, :set])

    children =
      [
        whisper_serving? && {Nx.Serving, name: LiveBeats.WhisperServing, serving: load_serving()},
        !parent && {DNSCluster, query: Application.get_env(:wps, :dns_cluster_query) || :ignore},
        {Task.Supervisor, name: LiveBeats.TaskSupervisor},
        # Start the Ecto repository
        LiveBeats.Repo,
        # Start the Telemetry supervisor
        LiveBeatsWeb.Telemetry,
        # Start the PubSub system
        {Phoenix.PubSub, name: LiveBeats.PubSub},
        # start presence
        !parent && LiveBeatsWeb.Presence,
        {Finch, name: LiveBeats.Finch},
        {FLAME.Pool,
         name: LiveBeats.WhisperRunner,
         min: 0,
         max: 5,
         max_concurrency: 10,
         min_idle_shutdown_after: :timer.seconds(30),
         idle_shutdown_after: :timer.seconds(30),
         log: :info},
        {LiveBeats.Streaming.Relay, node_type: :viewer_relay},
        # Start the Endpoint (http/https)
        !parent && LiveBeatsWeb.Endpoint,
        # Expire songs every six hours
        !parent && {LiveBeats.SongsCleaner, interval: {3600 * 6, :second}}
        # Start a worker by calling: LiveBeats.Worker.start_link(arg)
        # {LiveBeats.Worker, arg}
      ]
      |> Enum.filter(& &1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LiveBeats.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LiveBeatsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
