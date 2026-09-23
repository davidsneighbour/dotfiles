import { useMemo, useState } from "react";
import { ClientManagerDialog } from "@/components/client-manager";
import { ProjectManagerDialog } from "@/components/project-manager";
import { Button } from "@/components/ui/button";
import { Combobox } from "@/components/ui/combobox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";

type ClientItem = { id: string; name: string };

type ProjectItem = {
  id: string;
  name: string;
  clientId: string | undefined;
  color: string | undefined;
};

type TagItem = { id: string; name: string };

type RecentEntry = { projectId: string; title: string };

type FormPageContext = {
  projects: ProjectItem[];
  clients: ClientItem[];
  tags: TagItem[];
  selectedProjectId: string | undefined;
  selectedTagIds: string[];
  title: string;
  start: string;
  end: string;
  lastEntryEnd: string | null;
  recentEntries: RecentEntry[];
};

declare global {
  interface Window {
    __CLOCKIFY_CONTEXT__: FormPageContext;
  }
}

const context = window.__CLOCKIFY_CONTEXT__;

const RECENT_PROJECT_LIMIT = 8;
const TITLE_SUGGESTION_LIMIT = 6;

type SubmitResponse = { ok: true } | { ok: false; error: string };
type TagCreateResponse =
  | { ok: true; tags: TagItem[] }
  | { ok: false; error: string };

function localDateInputValue(value: Date): string {
  const offsetMs = value.getTimezoneOffset() * 60_000;
  return new Date(value.getTime() - offsetMs).toISOString().slice(0, 16);
}

type TitleSuggestion = { key: string; title: string; muted: boolean };

export function App() {
  const [clients, setClients] = useState(context.clients);
  const [projects, setProjects] = useState(context.projects);
  const [tags, setTags] = useState(context.tags);
  const [projectId, setProjectId] = useState(context.selectedProjectId ?? "");
  const [projectQuery, setProjectQuery] = useState(
    projects.find((project) => project.id === context.selectedProjectId)
      ?.name ?? "",
  );
  const [title, setTitle] = useState(context.title);
  const [start, setStart] = useState(context.start);
  const [end, setEnd] = useState(context.end);
  const [tagIds, setTagIds] = useState<string[]>(context.selectedTagIds);
  const [newTagName, setNewTagName] = useState("");
  const [tagBusy, setTagBusy] = useState(false);
  const [tagError, setTagError] = useState<string | undefined>(undefined);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | undefined>(undefined);
  const [saved, setSaved] = useState(false);

  const recentProjectIds = useMemo(() => {
    const seen = new Set<string>();
    const ids: string[] = [];
    for (const entry of context.recentEntries) {
      if (!seen.has(entry.projectId)) {
        seen.add(entry.projectId);
        ids.push(entry.projectId);
      }
    }
    return ids;
  }, []);

  const projectItems = useMemo(() => {
    const query = projectQuery.trim().toLowerCase();
    if (query === "") {
      const recent = recentProjectIds
        .map((id) => projects.find((project) => project.id === id))
        .filter((project): project is ProjectItem => project !== undefined)
        .slice(0, RECENT_PROJECT_LIMIT);
      return recent.length > 0
        ? recent
        : projects.slice(0, RECENT_PROJECT_LIMIT);
    }
    return projects.filter((project) =>
      project.name.toLowerCase().includes(query),
    );
  }, [projectQuery, projects, recentProjectIds]);

  const titleItems = useMemo(() => {
    const query = title.trim().toLowerCase();
    const seen = new Set<string>();
    const own: TitleSuggestion[] = [];
    const other: TitleSuggestion[] = [];
    for (const entry of context.recentEntries) {
      if (query !== "" && !entry.title.toLowerCase().includes(query)) {
        continue;
      }
      const key = entry.title.toLowerCase();
      if (seen.has(key)) {
        continue;
      }
      const isOwn = entry.projectId === projectId;
      const bucket = isOwn ? own : other;
      if (bucket.length >= TITLE_SUGGESTION_LIMIT) {
        continue;
      }
      seen.add(key);
      bucket.push({
        key: `${entry.projectId}\u0000${entry.title}`,
        title: entry.title,
        muted: !isOwn,
      });
    }
    return [...own, ...other];
  }, [title, projectId]);

  const handleAddTag = async () => {
    const name = newTagName.trim();
    if (name === "") {
      return;
    }
    setTagBusy(true);
    setTagError(undefined);
    const response = await fetch("/api/tags/create", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ name }),
    });
    const result = (await response.json()) as TagCreateResponse;
    setTagBusy(false);
    if (!result.ok) {
      setTagError(result.error);
      return;
    }
    setTags(result.tags);
    setNewTagName("");
    const created = result.tags.find(
      (tag) => tag.name.toLowerCase() === name.toLowerCase(),
    );
    if (created !== undefined) {
      setTagIds((current) =>
        current.includes(created.id) ? current : [...current, created.id],
      );
    }
  };

  const toggleTag = (tagId: string) => {
    setTagIds((current) =>
      current.includes(tagId)
        ? current.filter((id) => id !== tagId)
        : [...current, tagId],
    );
  };

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setSubmitting(true);
    setError(undefined);
    try {
      const response = await fetch("/api/submit", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ projectId, title, start, end, tagIds }),
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
                onCreated={(id) => {
                  setProjectId(id);
                  setProjectQuery(
                    projects.find((project) => project.id === id)?.name ?? "",
                  );
                }}
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
          <Combobox
            id="project"
            value={projectQuery}
            onValueChange={(value) => {
              setProjectQuery(value);
              if (value.trim() === "") {
                setProjectId("");
              }
            }}
            items={projectItems}
            getKey={(project) => project.id}
            renderItem={(project) => (
              <span className="flex items-center gap-2">
                <span
                  className="size-2.5 shrink-0 rounded-full"
                  style={{ backgroundColor: project.color ?? "#999999" }}
                />
                <span className="truncate">{project.name}</span>
              </span>
            )}
            onSelect={(project) => {
              setProjectId(project.id);
              setProjectQuery(project.name);
            }}
            placeholder="Select or type a project"
            required
            emptyMessage="No matching projects."
          />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor="title">Title</Label>
          <Combobox
            id="title"
            value={title}
            onValueChange={setTitle}
            items={titleItems}
            getKey={(item) => item.key}
            renderItem={(item) => (
              <span
                className={cn(
                  "truncate",
                  item.muted && "text-muted-foreground",
                )}
              >
                {item.title}
              </span>
            )}
            onSelect={(item) => setTitle(item.title)}
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
            <div className="flex items-center justify-between">
              <Label htmlFor="end">End</Label>
              <div className="flex gap-2 text-xs">
                <button
                  type="button"
                  className="text-primary underline-offset-4 hover:underline"
                  onClick={() => setEnd(localDateInputValue(new Date()))}
                >
                  Now
                </button>
              </div>
            </div>
            <Input
              id="end"
              type="datetime-local"
              value={end}
              onChange={(event) => setEnd(event.target.value)}
            />
          </div>
        </div>
        <div className="space-y-1.5">
          <Label>Tags</Label>
          <div className="flex flex-wrap gap-1.5">
            {tags.map((tag) => {
              const active = tagIds.includes(tag.id);
              return (
                <button
                  key={tag.id}
                  type="button"
                  onClick={() => toggleTag(tag.id)}
                  className={cn(
                    "rounded-full border px-2.5 py-0.5 text-xs transition-colors",
                    active
                      ? "border-primary bg-primary text-primary-foreground"
                      : "border-input bg-card text-muted-foreground hover:bg-secondary/50",
                  )}
                >
                  {tag.name}
                </button>
              );
            })}
            {tags.length === 0 && (
              <span className="text-xs text-muted-foreground">
                No tags yet.
              </span>
            )}
          </div>
          <div className="flex gap-2">
            <Input
              placeholder="New tag"
              value={newTagName}
              onChange={(event) => setNewTagName(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === "Enter") {
                  event.preventDefault();
                  void handleAddTag();
                }
              }}
            />
            <Button
              type="button"
              size="sm"
              disabled={tagBusy || newTagName.trim() === ""}
              onClick={() => void handleAddTag()}
            >
              Add
            </Button>
          </div>
          {tagError !== undefined && (
            <p className="text-sm text-destructive">{tagError}</p>
          )}
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
