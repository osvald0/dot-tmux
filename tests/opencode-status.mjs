import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const source = process.argv[2] || join(root, "agents/opencode/tmux-agent-status.js");
const reports = [];
const watchers = [];
const context = vm.createContext({
  process: { env: {}, pid: 123, cwd: () => "/project" },
});
const childProcess = new vm.SyntheticModule(["execFile", "spawn"], function () {
  this.setExport("execFile", (executable, args, callback) => ({
    stdin: { end(input) { reports.push({ executable, args, input: JSON.parse(input) }); callback(); } },
  }));
  this.setExport("spawn", (executable, args) => {
    watchers.push({ executable, args });
    return { unref() {} };
  });
}, { context });
const os = new vm.SyntheticModule(["homedir"], function () {
  this.setExport("homedir", () => "/user");
}, { context });
const paths = new vm.SyntheticModule(["join"], function () {
  this.setExport("join", join);
}, { context });
const plugin = new vm.SourceTextModule(await readFile(source, "utf8"), { context });
const modules = { "node:child_process": childProcess, "node:os": os, "node:path": paths };
await plugin.link((specifier) => modules[specifier]);
await plugin.evaluate();
const handlers = await plugin.namespace.TmuxAgentStatusPlugin();
assert.equal(typeof handlers.event, "function", "outside-tmux sessions must still report events");
assert.equal(watchers.length, 1, "quitting before a prompt must still clear pane ownership");
await handlers["chat.message"]({ sessionID: "ses_root" });
await handlers.event({ event: { type: "session.status", properties: { sessionID: "ses_root", status: "busy" } } });
assert.equal(watchers.length, 2, "one process watcher and one watcher per conversation");
assert.equal(JSON.parse(watchers[1].args[4]).session_id, "ses_root");
assert.equal(reports.at(-1).args[1], "opencode");
assert.equal(reports.at(-1).args[2], "123");
assert.equal(reports.at(-1).input.cwd, "/project");
const count = reports.length;
await handlers.event({ event: { type: "session.created", properties: { info: { id: "ses_child", parentID: "ses_root" } } } });
await handlers["chat.message"]({ sessionID: "ses_child" });
await handlers.event({ event: { type: "session.idle", properties: { sessionID: "ses_child" } } });
assert.equal(reports.length, count, "child events must not replace the root conversation");
await handlers.event({ event: { type: "session.idle", properties: { sessionID: "ses_root" } } });
assert.equal(reports.at(-1).args[0], "done");
console.log("opencode outside-tmux events, session exit identity, and subagent isolation passed.");
