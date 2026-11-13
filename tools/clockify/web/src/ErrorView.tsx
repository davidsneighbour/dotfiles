import { useState } from "react";
import { Button } from "@/components/ui/button";

export type FormPageError = {
  message: string;
  details: unknown;
};

declare global {
  interface Window {
    __CLOCKIFY_ERROR__?: FormPageError;
  }
}

function formatDetails(details: unknown): string {
  return typeof details === "string"
    ? details
    : JSON.stringify(details, null, 2);
}

export function ErrorView({ error }: { error: FormPageError }) {
  const [opening, setOpening] = useState(false);
  const [failed, setFailed] = useState(false);

  const openClockify = async () => {
    setOpening(true);
    setFailed(false);
    try {
      const response = await fetch("/api/open-clockify", { method: "POST" });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      window.close();
    } catch (cause) {
      console.error("Opening the Clockify website failed", cause);
      setFailed(true);
      setOpening(false);
    }
  };

  return (
    <main className="mx-auto max-w-md p-8">
      <h1 className="text-lg font-semibold">Clockify</h1>
      <p role="alert" className="mt-6 text-sm text-destructive">
        {error.message}
      </p>
      {error.details !== null && error.details !== undefined && (
        <pre className="mt-4 max-h-80 overflow-auto rounded-md border border-secondary bg-secondary/40 p-3 font-mono text-xs leading-relaxed whitespace-pre-wrap break-words">
          {formatDetails(error.details)}
        </pre>
      )}
      {failed && (
        <p className="mt-4 text-sm text-destructive">
          The Clockify website could not be opened. Open
          https://app.clockify.me/tracker manually.
        </p>
      )}
      <Button
        type="button"
        className="mt-6 w-full"
        disabled={opening}
        onClick={() => void openClockify()}
      >
        {opening ? "Opening…" : "Open Clockify website and close"}
      </Button>
    </main>
  );
}
