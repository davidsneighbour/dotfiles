import { useState } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";

type ClientItem = { id: string; name: string };

type ProjectItem = {
  id: string;
  name: string;
  clientId: string | undefined;
  color: string | undefined;
};

type ApiResult =
  | { ok: true; clients: ClientItem[]; projects: ProjectItem[] }
  | { ok: false; error: string };

async function postJson(path: string, body: unknown): Promise<ApiResult> {
  const response = await fetch(path, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  return (await response.json()) as ApiResult;
}

export function ClientManagerDialog({
  clients,
  onChanged,
  trigger,
}: {
  clients: ClientItem[];
  onChanged: (clients: ClientItem[], projects: ProjectItem[]) => void;
  trigger: React.ReactNode;
}) {
  const [open, setOpen] = useState(false);
  const [newName, setNewName] = useState("");
  const [editingId, setEditingId] = useState<string | undefined>(undefined);
  const [editingName, setEditingName] = useState("");
  const [error, setError] = useState<string | undefined>(undefined);
  const [busy, setBusy] = useState(false);

  const handleAdd = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (newName.trim() === "") {
      return;
    }
    setBusy(true);
    setError(undefined);
    const result = await postJson("/api/clients/create", {
      name: newName.trim(),
    });
    setBusy(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setNewName("");
    onChanged(result.clients, result.projects);
  };

  const startEdit = (client: ClientItem) => {
    setEditingId(client.id);
    setEditingName(client.name);
  };

  const saveEdit = async () => {
    if (editingId === undefined || editingName.trim() === "") {
      return;
    }
    setBusy(true);
    setError(undefined);
    const result = await postJson("/api/clients/update", {
      id: editingId,
      name: editingName.trim(),
    });
    setBusy(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setEditingId(undefined);
    onChanged(result.clients, result.projects);
  };

  const archive = async (client: ClientItem) => {
    setBusy(true);
    setError(undefined);
    const result = await postJson("/api/clients/update", {
      id: client.id,
      archived: true,
    });
    setBusy(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    onChanged(result.clients, result.projects);
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>{trigger}</DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Clients</DialogTitle>
        </DialogHeader>
        <form className="flex gap-2" onSubmit={handleAdd}>
          <Input
            placeholder="New client name"
            value={newName}
            onChange={(event) => setNewName(event.target.value)}
          />
          <Button type="submit" disabled={busy || newName.trim() === ""}>
            Add
          </Button>
        </form>
        {error !== undefined && (
          <p className="mt-2 text-sm text-destructive">{error}</p>
        )}
        <ul className="mt-4 max-h-64 space-y-1 overflow-y-auto">
          {clients.map((client) => (
            <li
              key={client.id}
              className="flex items-center gap-2 rounded-md px-2 py-1.5 hover:bg-secondary/50"
            >
              {editingId === client.id ? (
                <>
                  <Input
                    autoFocus
                    value={editingName}
                    onChange={(event) => setEditingName(event.target.value)}
                    className="h-8"
                  />
                  <Button
                    type="button"
                    size="sm"
                    disabled={busy}
                    onClick={saveEdit}
                  >
                    Save
                  </Button>
                  <Button
                    type="button"
                    size="sm"
                    variant="ghost"
                    onClick={() => setEditingId(undefined)}
                  >
                    Cancel
                  </Button>
                </>
              ) : (
                <>
                  <span className="flex-1 text-sm">{client.name}</span>
                  <Button
                    type="button"
                    size="sm"
                    variant="ghost"
                    onClick={() => startEdit(client)}
                  >
                    Edit
                  </Button>
                  <Button
                    type="button"
                    size="sm"
                    variant="destructive"
                    disabled={busy}
                    onClick={() => archive(client)}
                  >
                    Delete
                  </Button>
                </>
              )}
            </li>
          ))}
          {clients.length === 0 && (
            <li className="text-sm text-muted-foreground">No clients yet.</li>
          )}
        </ul>
      </DialogContent>
    </Dialog>
  );
}
