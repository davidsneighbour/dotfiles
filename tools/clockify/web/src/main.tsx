import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "@/App";
import { ErrorView } from "@/ErrorView";
import "@/index.css";

const rootElement = document.getElementById("root");
if (rootElement === null) {
  throw new Error("Missing #root element.");
}

// The server injects __CLOCKIFY_ERROR__ instead of the form context when
// loading the form data failed, for example because of a rate limit.
const pageError = window.__CLOCKIFY_ERROR__;

createRoot(rootElement).render(
  <StrictMode>
    {pageError === undefined ? <App /> : <ErrorView error={pageError} />}
  </StrictMode>,
);
