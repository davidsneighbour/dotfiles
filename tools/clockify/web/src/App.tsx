import { useEffect, useMemo, useState } from "react";
import { ClientManagerDialog } from "@/components/client-manager";
import { ProjectManagerDialog } from "@/components/project-manager";
import { Button } from "@/components/ui/button";
import { Combobox } from "@/components/ui/combobox";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";
import { suggestedTags, tagClass, tagClasses } from "../../src/tag-classes.ts";

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
  runningEntryId: string | null;
  notice: string | null;
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
type RunningResponse =
  | { ok: true; runningEntryId: string | null; notice: string | null }
  | { ok: false; error: string };
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
  const [newTagOpen, setNewTagOpen] = useState(false);
  const [newTagName, setNewTagName] = useState("");
  const [newTagClass, setNewTagClass] = useState<string>("for");
  const [editingTagId, setEditingTagId] = useState<string | undefined>();
  const [expandedClasses, setExpandedClasses] = useState<string[]>([]);
  const availableTags = [
    ...tags,
    ...suggestedTags
      .filter((name) => !tags.some((tag) => tag.name.toLowerCase() === name))
      .map((name) => ({ id: `suggested:${name}`, name })),
  ];
  const [tagBusy, setTagBusy] = useState(false);
  const [tagError, setTagError] = useState<string | undefined>(undefined);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | undefined>(undefined);
  const [saved, setSaved] = useState(false);
  const [notice, setNotice] = useState(context.notice);
  const [runningChanged, setRunningChanged] = useState(false);

  // On window activation, ask the local server whether the running timer
  // changed. The server limits how often it asks Clockify.
  useEffect(() => {
    let checking = false;
    const check = async () => {
      if (checking || document.visibilityState !== "visible") return;
      checking = true;
      try {
        const response = await fetch("/api/running");
        const result = (await response.json()) as RunningResponse;
        if (!result.ok) return;
        setNotice(result.notice);
        setRunningChanged(result.runningEntryId !== context.runningEntryId);
      } catch (error) {
        console.error("Checking the running timer failed", error);
      } finally {
        checking = false;
      }
    };
    const onFocus = () => void check();
    window.addEventListener("focus", onFocus);
    document.addEventListener("visibilitychange", onFocus);
    return () => {
      window.removeEventListener("focus", onFocus);
      document.removeEventListener("visibilitychange", onFocus);
    };
  }, []);

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

  const toggleTag = (tagId: string) => {
    const prefix = tagClass(
      availableTags.find((tag) => tag.id === tagId)?.name ?? "",
    );
    setTagIds((current) =>
      current.includes(tagId)
        ? current.filter((id) => id !== tagId)
        : [
            ...current.filter(
              (id) =>
                !["for", "type", "activity"].includes(prefix) ||
                tagClass(
                  availableTags.find((tag) => tag.id === id)?.name ?? "",
                ) !== prefix,
            ),
            tagId,
          ],
    );
  };

  const handleAddTag = async () => {
    const name = `${newTagClass}:${newTagName.trim()}`;
    setTagBusy(true);
    setTagError(undefined);
    try {
      const response = await fetch(
        editingTagId ? "/api/tags/edit" : "/api/tags/create",
        {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ name, id: editingTagId }),
        },
      );
      const result = (await response.json()) as TagCreateResponse;
      if (!result.ok) {
        setTagError(result.error);
        return;
      }
      setTags(result.tags);
      const created = result.tags.find(
        (tag) => tag.name.toLowerCase() === name.toLowerCase(),
      );
      if (created && !editingTagId) {
        setTagIds((current) => [
          ...current.filter(
            (id) =>
              id !== `suggested:${name}` &&
              (!["for", "type", "activity"].includes(newTagClass) ||
                tagClass(
                  availableTags.find((tag) => tag.id === id)?.name ?? "",
                ) !== newTagClass),
          ),
          created.id,
        ]);
      }
      setNewTagName("");
      setNewTagOpen(false);
      setEditingTagId(undefined);
    } catch (error) {
      console.error("Saving tag failed", error);
      setTagError("Saving the tag failed. Try again.");
    } finally {
      setTagBusy(false);
    }
  };

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setSubmitting(true);
    setError(undefined);
    try {
      const response = await fetch("/api/submit", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          projectId,
          title,
          start,
          end,
          tagIds,
          runningEntryId: context.runningEntryId,
        }),
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
      {runningChanged && (
        <div className="mt-4 flex items-center justify-between gap-3 rounded-md border border-destructive p-3 text-sm">
          <p>The running timer changed in Clockify.</p>
          <Button
            type="button"
            size="sm"
            onClick={() => window.location.reload()}
          >
            Reload
          </Button>
        </div>
      )}
      {notice !== null && (
        <p className="mt-4 text-sm text-muted-foreground">{notice}</p>
      )}
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
          <div className="flex items-center justify-between">
            <Label>Tags</Label>
            <div className="flex gap-2 text-xs">
              <button
                type="button"
                className="text-primary underline-offset-4 hover:underline"
                aria-expanded={newTagOpen}
                onClick={() => {
                  setEditingTagId(undefined);
                  setNewTagName("");
                  setNewTagOpen((open) => !open);
                  setTagError(undefined);
                }}
              >
                {newTagOpen ? "Cancel" : "New tag"}
              </button>
            </div>
          </div>
          <p className="text-xs text-muted-foreground">
            Choose one for: and type: tag. An activity: tag is recommended.
          </p>
          {[...tagClasses, { prefix: "other", color: "#f8f8f2" }].map(
            (group) => {
              const items = availableTags.filter(
                (tag) =>
                  (tagClasses.some((item) => item.prefix === tagClass(tag.name))
                    ? tagClass(tag.name)
                    : "other") === group.prefix,
              );
              const expanded = expandedClasses.includes(group.prefix);
              if (items.length === 0) return null;
              const shown = expanded
                ? items
                : items.filter(
                    (tag, index) => index < 3 || tagIds.includes(tag.id),
                  );
              return (
                <div key={group.prefix} className="flex items-start gap-2 py-1">
                  <span
                    className="w-16 shrink-0 pt-1 text-xs"
                    style={{ color: group.color }}
                  >
                    {group.prefix}:
                  </span>
                  <div
                    id={`tags-${group.prefix}`}
                    className="flex min-w-0 flex-1 flex-wrap gap-1.5"
                  >
                    {shown.map((tag) => {
                      const active = tagIds.includes(tag.id);
                      return (
                        <span
                          key={tag.id}
                          className="inline-flex rounded-full border"
                          style={{ borderColor: group.color }}
                        >
                          <button
                            type="button"
                            aria-pressed={active}
                            onClick={() => toggleTag(tag.id)}
                            className="rounded-full px-2.5 py-0.5 text-xs focus-visible:outline-2 focus-visible:outline-offset-2"
                            style={{
                              backgroundColor: active ? group.color : undefined,
                              color: active ? "#282a36" : group.color,
                            }}
                          >
                            {tag.name.slice(
                              group.prefix === "other"
                                ? 0
                                : group.prefix.length + 1,
                            )}
                          </button>
                          {!tag.id.startsWith("suggested:") && (
                            <button
                              type="button"
                              aria-label={`Edit ${tag.name}`}
                              className="px-1.5 text-xs"
                              onClick={() => {
                                setEditingTagId(tag.id);
                                const prefix = tagClass(tag.name);
                                setNewTagClass(
                                  tagClasses.some(
                                    (group) => group.prefix === prefix,
                                  )
                                    ? prefix
                                    : "for",
                                );
                                setNewTagName(
                                  !tagClasses.some(
                                    (group) => group.prefix === prefix,
                                  )
                                    ? tag.name
                                    : tag.name.slice(prefix.length + 1),
                                );
                                setNewTagOpen(true);
                                setTagError(undefined);
                              }}
                            >
                              ✎
                            </button>
                          )}
                        </span>
                      );
                    })}
                  </div>
                  {(items.length > 3 || expanded) && (
                    <button
                      type="button"
                      className="shrink-0 text-xs text-primary hover:underline"
                      aria-expanded={expanded}
                      aria-controls={`tags-${group.prefix}`}
                      onClick={() =>
                        setExpandedClasses((current) =>
                          expanded
                            ? current.filter(
                                (prefix) => prefix !== group.prefix,
                              )
                            : [...current, group.prefix],
                        )
                      }
                    >
                      {expanded ? "Less" : "More"}
                    </button>
                  )}
                </div>
              );
            },
          )}
          {newTagOpen && (
            <div className="space-y-2 rounded border border-input p-3">
              <fieldset className="flex flex-wrap gap-3">
                <legend className="mb-2 text-sm">
                  {editingTagId ? "Edit tag class" : "New tag class"}
                </legend>
                {tagClasses.map((group) => (
                  <label
                    key={group.prefix}
                    className="flex items-center gap-1 text-xs"
                    style={{ color: group.color }}
                  >
                    <input
                      type="radio"
                      name="tag-class"
                      value={group.prefix}
                      checked={newTagClass === group.prefix}
                      onChange={() => setNewTagClass(group.prefix)}
                    />
                    {group.prefix}:
                  </label>
                ))}
              </fieldset>
              {editingTagId && (
                <p className="text-xs text-muted-foreground">
                  Renaming changes this workspace tag on all entries that use
                  it.
                </p>
              )}
              <Label htmlFor="tag-value">Tag value</Label>
              <Input
                id="tag-value"
                placeholder="Tag value"
                value={newTagName}
                autoFocus
                onChange={(event) => setNewTagName(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === "Enter") {
                    event.preventDefault();
                    void handleAddTag();
                  } else if (event.key === "Escape") {
                    event.preventDefault();
                    setNewTagOpen(false);
                    setTagError(undefined);
                  }
                }}
              />
              <Button
                type="button"
                size="sm"
                disabled={tagBusy || newTagName.trim() === ""}
                onClick={() => void handleAddTag()}
              >
                {editingTagId ? "Save tag" : "Add"}
              </Button>
            </div>
          )}
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
