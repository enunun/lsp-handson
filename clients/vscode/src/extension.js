// Starts the Calc language server for .calc files and restarts it on request.
const path = require('node:path');
const vscode = require('vscode');
const { LanguageClient } = require('vscode-languageclient/node');

let client;

function serverPath() {
  const configured = vscode.workspace.getConfiguration('calc').get('server.path');
  const folder = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath ?? '';
  return path.isAbsolute(configured) ? configured : path.join(folder, configured);
}

async function start() {
  const command = serverPath();
  client = new LanguageClient(
    'calc',
    'Calc Language Server',
    { run: { command }, debug: { command } },
    { documentSelector: [{ scheme: 'file', language: 'calc' }] },
  );
  await client.start();
}

async function restart() {
  if (client) {
    await client.stop();
  }
  await start();
}

async function activate(context) {
  context.subscriptions.push(vscode.commands.registerCommand('calc.restartServer', restart));
  await start();
}

async function deactivate() {
  if (client) {
    await client.stop();
  }
}

module.exports = { activate, deactivate };
