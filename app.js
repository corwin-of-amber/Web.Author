const { app, BrowserWindow } = require('electron')
const fs = require('fs'),
      path = require('path');

var appdir = process.cwd(),
    m = JSON.parse(fs.readFileSync('package.json'));

process.env.ELECTRON_DISABLE_SECURITY_WARNINGS = true; // sorry Electron

let win

function createWindow () {
  win = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      nodeIntegration: true
    }
  });

  win.loadFile(path.resolve(appdir,
      (m.app && m.app.main) || m.main || 'index.html'));

  win.on('closed', () => { win = null });
}

app.on('ready', createWindow)
app.on('window-all-closed', () => { app.quit() });

