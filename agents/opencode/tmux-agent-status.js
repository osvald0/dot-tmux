// Reports opencode session state to tmux through tmux-agent-status, matching
// the Claude Code and Codex hooks: tab status icons plus the session id that
// tmux-resurrect-agent-save uses to restore the pane.

import { execFile, spawn } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

const STATUS_SCRIPT = join(homedir(), ".local/bin/tmux-agent-status");

const BUSY_STATUSES = new Set(["active", "busy", "pending", "retry", "running", "streaming", "working"]);

// Subagent sessions have a parent; their events must not replace the pane's root session.
const childSessions = new Set();
let queue = Promise.resolve();

function report(status, sessionID) {
  const input = JSON.stringify({ session_id: sessionID, cwd: process.cwd() });
  queue = queue.then(
    () =>
      new Promise((resolve) => {
        const child = execFile(STATUS_SCRIPT, [status, "opencode", String(process.pid)], () => resolve());
        child.stdin?.end(input);
      }),
  );
  return queue;
}

export const TmuxAgentStatusPlugin = async () => {
  if (!process.env.TMUX || !process.env.TMUX_PANE) {
    return {};
  }

  // Exit handlers do not run when the TUI quits, so a detached watcher clears the pane instead.
  spawn(
    "/bin/sh",
    ["-c", 'while kill -0 "$0" 2>/dev/null; do sleep 2; done; exec "$1" clear opencode "$0" </dev/null', String(process.pid), STATUS_SCRIPT],
    { detached: true, stdio: "ignore" },
  ).unref();

  await report("ready");

  return {
    "chat.message": async ({ sessionID }) => {
      if (sessionID && !childSessions.has(sessionID)) {
        await report("working", sessionID);
      }
    },
    event: async ({ event }) => {
      const properties = event?.properties ?? {};
      const info = properties.info;
      if (info?.id && info.parentID) {
        childSessions.add(info.id);
      }

      const sessionID = typeof properties.sessionID === "string" ? properties.sessionID : info?.id;
      if (!sessionID || childSessions.has(sessionID)) {
        return;
      }

      switch (event.type) {
        case "session.status": {
          const kind = typeof properties.status === "string" ? properties.status : properties.status?.type;
          if (BUSY_STATUSES.has(kind?.toLowerCase())) {
            await report("working", sessionID);
          }
          break;
        }
        case "permission.replied":
        case "question.replied":
        case "question.rejected":
          await report("working", sessionID);
          break;
        case "permission.asked":
        case "question.asked":
          await report("waiting", sessionID);
          break;
        case "session.error":
          await report("error", sessionID);
          break;
        case "session.idle":
          await report("done", sessionID);
          break;
        default:
          break;
      }
    },
  };
};

export default {
  id: "dot-tmux.agent-status",
  server: TmuxAgentStatusPlugin,
  setup() {},
};
