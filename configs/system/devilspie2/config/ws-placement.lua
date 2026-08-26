-- Generic one-shot workspace placement, driven by bashrc/workspaces/ws_launch_program.
--
-- ws_launch_program writes a state file per launched PID (before the target
-- program's window has a chance to open) at:
--   ${XDG_RUNTIME_DIR:-/tmp}/ws-launch-placements/<pid>
-- containing a single 1-based workspace number.
--
-- Devilspie2 has no get_window_pid(), so the PID is read back off the window
-- via the standard _NET_WM_PID property instead. Each state file is consumed
-- (read once, then deleted) so a request never fires twice and a reused PID
-- can never pick up a stale request.

local state_dir = os.getenv("XDG_RUNTIME_DIR")
if state_dir == nil or state_dir == "" then
    state_dir = "/tmp"
end
state_dir = state_dir .. "/ws-launch-placements"

local pid = get_window_property("_NET_WM_PID")

if pid ~= nil then
    local state_file = state_dir .. "/" .. tostring(pid)
    local file = io.open(state_file, "r")

    if file ~= nil then
        local workspace = file:read("*l")
        file:close()
        os.remove(state_file)

        local workspace_num = tonumber(workspace)
        if workspace_num ~= nil then
            debug_print("ws-placement: moving pid " .. tostring(pid) .. " to workspace " .. tostring(workspace_num))
            set_window_workspace(workspace_num)
        end
    end
end
