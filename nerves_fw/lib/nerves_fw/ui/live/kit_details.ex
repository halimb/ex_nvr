defmodule ExNVRWeb.KitDetailsLive do
  use ExNVRWeb, :live_view

  alias ExNVR.SystemStatus

  @refresh_interval 5_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_interval, self(), :refresh)
    end

    status = SystemStatus.get_all()
    form = to_form(%{"code" => ""}, as: "runner")

    {:ok, assign(socket, status: status, form: form, result: "")}
  end

  @impl true
  def handle_info(:refresh, socket) do
    status = SystemStatus.get_all()
    {:noreply, assign(socket, status: status)}
  end

  @impl true
  def handle_event("run", %{"runner" => %{"code" => code}}, socket) do
    result =
      try do
        {val, _} = Code.eval_string(code)
        inspect(val)
      rescue
        e -> "Error: " <> Exception.message(e)
      end

    {:noreply,
     socket
     |> assign(form: to_form(%{"code" => code}, as: "runner"), result: result)}
  end

  @impl true
  def render(assigns) do
    ~H"""

    <div class="grid grid-cols-2 gap-4 p-8 px-12 text-zinc-600 dark:text-white w-full">
      <div>
        <h2 class="text-2xl font-semibold mb-4">Kit System Status</h2>

        <section class="mb-6">
          <h3 class="text-xl font-medium mb-2">CPU</h3>
          <p>Load: <%= Enum.join(@status.cpu.load, ", ") %></p>
          <p>Cores: <%= @status.cpu.num_cores %></p>
        </section>

        <section class="mb-6">
          <h3 class="text-xl font-medium mb-2">Memory</h3>
          <p>Total: <%= format_bytes(@status.memory.total_memory) %></p>
          <p>Free: <%= format_bytes(@status.memory.free_memory) %></p>
          <p>Available: <%= format_bytes(@status.memory.available_memory) %></p>
        </section>

        <section class="mb-6">
          <h3 class="text-xl font-medium mb-2">Devices</h3>
          <ul>
            <%= for device <- @status.devices do %>
              <li class="mb-2">
                <strong><%= device.name %></strong> - <%= device.state %>
              </li>
            <% end %>
          </ul>
        </section>

        <section>
          <h3 class="text-xl font-medium mb-2">Storage</h3>
          <ul>
            <%= for disk <- @status.block_storage do %>
              <li class="mb-2">
                <strong><%= disk.name %></strong> (<%= disk.vendor %> <%= disk.model %>) - <%= format_bytes(disk.size) %>
              </li>
            <% end %>
          </ul>
        </section>
      </div>

      <div class="p-4">
        <h2 class="text-xl font-bold mb-4">Code Runner</h2>

        <.simple_form for={@form} id="code-runner-form" phx-submit="run">
          <.input
            field={@form[:code]}
            type="textarea"
            rows="10"
            label="Elixir Code"
            class="bg-gray-700 border-none text-white"
          />

          <:actions>
            <.button class="w-full bg-slate-700">
              Run
            </.button>
          </:actions>
        </.simple_form>

        <div :if={@result != ""} class="mt-6">
          <h3 class="font-semibold">Result:</h3>
          <pre class="bg-gray-700 p-3 rounded text-sm whitespace-pre-wrap"><%= @result %></pre>
        </div>
      </div>
    </div>
    """
  end

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_000_000_000 ->
        :io_lib.format("~.2f GB", [bytes / 1_000_000_000]) |> List.to_string()
      bytes >= 1_000_000 ->
        :io_lib.format("~.2f MB", [bytes / 1_000_000]) |> List.to_string()
      bytes >= 1_000 ->
        :io_lib.format("~.2f KB", [bytes / 1_000]) |> List.to_string()
      true ->
        "\#{bytes} B"
    end
  end
end
