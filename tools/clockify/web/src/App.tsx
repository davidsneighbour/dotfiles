import { useState } from "react";
import { ClientManagerDialog } from "@/components/client-manager";
import { ProjectManagerDialog } from "@/components/project-manager";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

type ClientItem = { id: string; name: string };

type ProjectItem = {
  id: string;
  name: string;
  clientId: string | undefined;
  color: string | undefined;
};

type FormPageContext = {
  projects: ProjectItem[];
  clients: ClientItem[];
  selectedProjectId: string | undefined;
  title: string;
  start: string;
  end: string;
  lastEntryEnd: string | null;
};

declare global {
  interface Window {
    __CLOCKIFY_CONTEXT__: FormPageContext;
  }
}

const context = window.__CLOCKIFY_CONTEXT__;

type SubmitResponse = { ok: true } | { ok: false; error: string };

function localDateInputValue(value: Date): string {
  const offsetMs = value.getTimezoneOffset() * 60_000;
  return new Date(value.getTime() - offsetMs).toISOString().slice(0, 16);
}

export function App() {
  const [clients, setClients] = useState(context.clients);
  const [projects, setProjects] = useState(context.projects);
  const [projectId, setProjectId] = useState(context.selectedProjectId ?? "");
  const [title, setTitle] = useState(context.title);
  const [start, setStart] = useState(context.start);
  const [end, setEnd] = useState(context.end);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | undefined>(undefined);
  const [saved, setSaved] = useState(false);

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setSubmitting(true);
    setError(undefined);
    try {
      const response = await fetch("/api/submit", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ projectId, title, start, end }),
      });
      const result = (await response.json()) as SubmitResponse;
      if (!result.ok) {
        setError(result.error);
        setSubmitting(false);
        return;
      }
      setSaved(true);
      window.close();
    } catch {
      setError("Submitting the Clockify form failed.");
      setSubmitting(false);
    }
  };

  if (saved) {
    return (
      <main className="mx-auto max-w-md p-8">
        <h1 className="text-lg font-semibold">Saved</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          You can close this window.
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-md p-8">
      <h1 className="text-lg font-semibold">Clockify</h1>
      <form className="mt-6 space-y-4" onSubmit={handleSubmit}>
        <div className="space-y-1.5">
          <div className="flex items-center justify-between">
            <Label htmlFor="project">Project</Label>
            <div className="flex gap-3 text-xs">
              <ClientManagerDialog
                clients={clients}
                onChanged={(nextClients, nextProjects) => {
                  setClients(nextClients);
                  setProjects(nextProjects);
                }}
                trigger={
                  <button
                    type="button"
                    className="text-primary underline-offset-4 hover:underline"
                  >
                    Clients
                  </button>
                }
              />
              <ProjectManagerDialog
                clients={clients}
                projects={projects}
                onChanged={(nextClients, nextProjects) => {
                  setClients(nextClients);
                  setProjects(nextProjects);
                }}
                onCreated={setProjectId}
                trigger={
                  <button
                    type="button"
                    className="text-primary underline-offset-4 hover:underline"
                  >
                    Projects
                  </button>
                }
              />
            </div>
          </div>
          <Select value={projectId} onValueChange={setProjectId}>
            <SelectTrigger id="project">
              <SelectValue placeholder="Select a project" />
            </SelectTrigger>
            <SelectContent>
              {projects.map((project) => (
                <SelectItem key={project.id} value={project.id}>
                  {project.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="title">Title</Label>
          <Input
            id="title"
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            required
          />
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <Label htmlFor="start">Start</Label>
              <div className="flex gap-2 text-xs">
                <button
                  type="button"
                  className="text-primary underline-offset-4 hover:underline disabled:pointer-events-none disabled:opacity-50"
                  disabled={context.lastEntryEnd === null}
                  onClick={() =>
                    setStart(
                      localDateInputValue(new Date(context.lastEntryEnd ?? "")),
                    )
                  }
                >
                  From last entry
                </button>
                <button
                  type="button"
                  className="text-primary underline-offset-4 hover:underline"
                  onClick={() => setStart(localDateInputValue(new Date()))}
                >
                  Now
                </button>
              </div>
            </div>
            <Input
              id="start"
              type="datetime-local"
              value={start}
              onChange={(event) => setStart(event.target.value)}
              required
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="end">End</Label>
            <Input
              id="end"
              type="datetime-local"
              value={end}
              onChange={(event) => setEnd(event.target.value)}
            />
          </div>
        </div>
        {error !== undefined && (
          <p className="text-sm text-destructive">{error}</p>
        )}
        <div className="flex gap-2">
          <Button type="submit" disabled={submitting} className="flex-1">
            {submitting ? "Saving…" : "Save"}
          </Button>
          <Button
            type="button"
            variant="secondary"
            onClick={() => window.close()}
          >
            Close
          </Button>
        </div>
      </form>
    </main>
  );
}
