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
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { defaultProjectColor, projectColors } from "@/lib/colors";

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

function ColorSwatches({
  value,
  onChange,
}: {
  value: string;
  onChange: (color: string) => void;
}) {
  return (
    <div className="flex flex-wrap gap-2">
      {projectColors.map((color) => (
        <button
          key={color}
          type="button"
          aria-label={color}
          aria-pressed={value === color}
          onClick={() => onChange(color)}
          className={`size-6 rounded-full ${
            value === color
              ? "ring-2 ring-ring ring-offset-2 ring-offset-card"
              : ""
          }`}
          style={{ backgroundColor: color }}
        />
      ))}
    </div>
  );
}

type FormState = { name: string; clientId: string; color: string };

const emptyForm: FormState = {
  name: "",
  clientId: "",
  color: defaultProjectColor,
};

export function ProjectManagerDialog({
  clients,
  projects,
  onChanged,
  onCreated,
  trigger,
}: {
  clients: ClientItem[];
  projects: ProjectItem[];
  onChanged: (clients: ClientItem[], projects: ProjectItem[]) => void;
  onCreated: (projectId: string) => void;
  trigger: React.ReactNode;
}) {
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState<FormState>(emptyForm);
  const [editingId, setEditingId] = useState<string | undefined>(undefined);
  const [newClientName, setNewClientName] = useState("");
  const [addingClient, setAddingClient] = useState(false);
  const [error, setError] = useState<string | undefined>(undefined);
  const [busy, setBusy] = useState(false);

  const resetForm = () => {
    setForm(emptyForm);
    setEditingId(undefined);
    setAddingClient(false);
    setNewClientName("");
  };

  const startEdit = (project: ProjectItem) => {
    setEditingId(project.id);
    setForm({
      name: project.name,
      clientId: project.clientId ?? "",
      color: project.color ?? defaultProjectColor,
    });
  };

  const handleAddClient = async () => {
    if (newClientName.trim() === "") {
      return;
    }
    setBusy(true);
    setError(undefined);
    const result = await postJson("/api/clients/create", {
      name: newClientName.trim(),
    });
    setBusy(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    const created = result.clients.find(
      (client) => !clients.some((existing) => existing.id === client.id),
    );
    onChanged(result.clients, result.projects);
    setForm((current) => ({
      ...current,
      clientId: created?.id ?? current.clientId,
    }));
    setNewClientName("");
    setAddingClient(false);
  };

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (form.name.trim() === "" || form.clientId === "") {
      return;
    }
    setBusy(true);
    setError(undefined);
    const result =
      editingId === undefined
        ? await postJson("/api/projects/create", {
            name: form.name.trim(),
            clientId: form.clientId,
            color: form.color,
          })
        : await postJson("/api/projects/update", {
            id: editingId,
            name: form.name.trim(),
            clientId: form.clientId,
            color: form.color,
          });
    setBusy(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    if (editingId === undefined) {
      const created = result.projects.find(
        (project) => !projects.some((existing) => existing.id === project.id),
      );
      onChanged(result.clients, result.projects);
      if (created !== undefined) {
        onCreated(created.id);
      }
      resetForm();
      setOpen(false);
      return;
    }
    onChanged(result.clients, result.projects);
    resetForm();
  };

  const archive = async (project: ProjectItem) => {
    setBusy(true);
    setError(undefined);
    const result = await postJson("/api/projects/update", {
      id: project.id,
      archived: true,
    });
    setBusy(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    onChanged(result.clients, result.projects);
  };

  const clientName = (clientId: string | undefined) =>
    clients.find((client) => client.id === clientId)?.name ?? "—";

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        setOpen(next);
        if (!next) {
          resetForm();
        }
      }}
    >
      <DialogTrigger asChild>{trigger}</DialogTrigger>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>
            {editingId === undefined ? "Add project" : "Edit project"}
          </DialogTitle>
        </DialogHeader>
        <form className="space-y-3" onSubmit={handleSubmit}>
          <div className="space-y-1.5">
            <Label htmlFor="project-name">Name</Label>
            <Input
              id="project-name"
              value={form.name}
              onChange={(event) =>
                setForm((current) => ({ ...current, name: event.target.value }))
              }
              required
            />
          </div>
          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <Label htmlFor="project-client">Client</Label>
              <button
                type="button"
                className="text-xs text-primary underline-offset-4 hover:underline"
                onClick={() => setAddingClient((current) => !current)}
              >
                + New client
              </button>
            </div>
            {addingClient && (
              <div className="flex gap-2">
                <Input
                  autoFocus
                  placeholder="Client name"
                  value={newClientName}
                  onChange={(event) => setNewClientName(event.target.value)}
                />
                <Button
                  type="button"
                  size="sm"
                  disabled={busy}
                  onClick={handleAddClient}
                >
                  Add
                </Button>
              </div>
            )}
            <Select
              value={form.clientId}
              onValueChange={(value) =>
                setForm((current) => ({ ...current, clientId: value }))
              }
            >
              <SelectTrigger id="project-client">
                <SelectValue placeholder="Select a client" />
              </SelectTrigger>
              <SelectContent>
                {clients.map((client) => (
                  <SelectItem key={client.id} value={client.id}>
                    {client.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-1.5">
            <Label>Color</Label>
            <ColorSwatches
              value={form.color}
              onChange={(color) =>
                setForm((current) => ({ ...current, color }))
              }
            />
          </div>
          {error !== undefined && (
            <p className="text-sm text-destructive">{error}</p>
          )}
          <div className="flex gap-2">
            <Button type="submit" disabled={busy} className="flex-1">
              {editingId === undefined ? "Add project" : "Save changes"}
            </Button>
            {editingId !== undefined && (
              <Button type="button" variant="secondary" onClick={resetForm}>
                Cancel
              </Button>
            )}
          </div>
        </form>
        <ul className="mt-4 max-h-56 space-y-1 overflow-y-auto border-t border-border pt-3">
          {projects.map((project) => (
            <li
              key={project.id}
              className="flex items-center gap-2 rounded-md px-2 py-1.5 hover:bg-secondary/50"
            >
              <span
                className="size-3 shrink-0 rounded-full"
                style={{ backgroundColor: project.color ?? "#999999" }}
              />
              <span className="flex-1 truncate text-sm">
                {project.name}{" "}
                <span className="text-muted-foreground">
                  — {clientName(project.clientId)}
                </span>
              </span>
              <Button
                type="button"
                size="sm"
                variant="ghost"
                onClick={() => startEdit(project)}
              >
                Edit
              </Button>
              <Button
                type="button"
                size="sm"
                variant="destructive"
                disabled={busy}
                onClick={() => archive(project)}
              >
                Delete
              </Button>
            </li>
          ))}
          {projects.length === 0 && (
            <li className="text-sm text-muted-foreground">No projects yet.</li>
          )}
        </ul>
      </DialogContent>
    </Dialog>
  );
}
