# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT

# Opens a stand-in for a game so subtitle mode can be tried without one.
#
# The window shows English dialogue at the bottom centre and a changing
# quest objective in the top-left corner, both drawn like game text. Pick
# LoreDubOcrTest.exe in the process list, draw the frame in Settings, start
# dubbing and switch to this window: only the text inside the frame should
# reach the transcript. Esc closes it.
#
# It is compiled into its own executable so it shows up under a name of its
# own in the process list, rather than as one more powershell.exe.

param(
  [switch]$Fullscreen,
  [switch]$PassThru
)

$ErrorActionPreference = "Stop"
$OutputDirectory = Join-Path $PSScriptRoot "..\build\ocr_test"
$Executable = Join-Path $OutputDirectory "LoreDubOcrTest.exe"

$Source = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class LoreDubOcrTest {
  [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr window);
  [DllImport("user32.dll")] static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);

  static readonly string[] Subtitles = {
    "You should not have come back here, traveler.",
    "The lighthouse has been dark for three winters.",
    "If the keeper is alive, he will be on the cliffs.",
    "Take the lantern. You will need it below.",
    "I heard the bells again last night.",
    "Nobody crosses the marsh after sunset.",
  };

  static readonly string[] Objectives = {
    "Objective: Find the lighthouse keeper",
    "Objective: Light the signal fire",
    "Objective: Search the old harbor",
    "Objective: Return to the village",
  };

  [STAThread]
  public static void Main(string[] args) {
    // Crisp text on a scaled display, as a game would draw it.
    SetProcessDPIAware();
    Application.EnableVisualStyles();
    Application.Run(new Scene(Array.IndexOf(args, "--fullscreen") >= 0));
  }

  // Windows only lets a process take the foreground in a few cases; a
  // released Alt key is one of them, which is enough for a test window.
  public static void TakeForeground(IntPtr window) {
    keybd_event(0x12, 0, 0, UIntPtr.Zero);
    keybd_event(0x12, 0, 2, UIntPtr.Zero);
    SetForegroundWindow(window);
  }

  class Scene : Form {
    int subtitle;
    int objective;

    public Scene(bool fullscreen) {
      Text = "LoreDub OCR test - Esc closes";
      BackColor = Color.FromArgb(18, 20, 24);
      DoubleBuffered = true;
      KeyPreview = true;
      if (fullscreen) {
        FormBorderStyle = FormBorderStyle.None;
        WindowState = FormWindowState.Maximized;
      } else {
        ClientSize = new Size(1280, 720);
        StartPosition = FormStartPosition.CenterScreen;
      }
      var subtitleTimer = new Timer { Interval = 4000 };
      subtitleTimer.Tick += (sender, e) => { subtitle = (subtitle + 1) % Subtitles.Length; Invalidate(); };
      subtitleTimer.Start();
      var objectiveTimer = new Timer { Interval = 5000 };
      objectiveTimer.Tick += (sender, e) => { objective = (objective + 1) % Objectives.Length; Invalidate(); };
      objectiveTimer.Start();
      KeyDown += (sender, e) => { if (e.KeyCode == Keys.Escape) Close(); };
      Resize += (sender, e) => Invalidate();
    }

    protected override void OnShown(EventArgs e) {
      base.OnShown(e);
      TakeForeground(Handle);
      Activate();
    }

    protected override void OnPaint(PaintEventArgs e) {
      var g = e.Graphics;
      g.SmoothingMode = SmoothingMode.AntiAlias;
      var size = ClientSize;
      if (size.Width < 10 || size.Height < 10) return;
      // A dusk sky and a line of hills, so the text sits on a picture
      // rather than on a flat colour OCR would find too easy.
      using (var sky = new LinearGradientBrush(ClientRectangle, Color.FromArgb(58, 72, 104),
                                               Color.FromArgb(22, 24, 30), 90f)) {
        g.FillRectangle(sky, ClientRectangle);
      }
      using (var hills = new GraphicsPath()) {
        hills.AddBezier(0, size.Height * 0.62f, size.Width * 0.3f, size.Height * 0.48f,
                        size.Width * 0.6f, size.Height * 0.72f, size.Width, size.Height * 0.56f);
        hills.AddLine(size.Width, size.Height * 0.56f, size.Width, size.Height);
        hills.AddLine(size.Width, size.Height, 0, size.Height);
        hills.CloseFigure();
        using (var ground = new SolidBrush(Color.FromArgb(30, 44, 36))) g.FillPath(ground, hills);
      }
      DrawOutlined(g, Objectives[objective], size.Height * 0.032f,
                   new PointF(size.Width * 0.03f, size.Height * 0.05f), false,
                   Color.FromArgb(255, 214, 120));
      DrawOutlined(g, Subtitles[subtitle], size.Height * 0.045f,
                   new PointF(size.Width / 2f, size.Height * 0.84f), true, Color.White);
    }

    static void DrawOutlined(Graphics g, string text, float pixels, PointF at, bool centered,
                             Color color) {
      using (var family = new FontFamily("Segoe UI"))
      using (var path = new GraphicsPath())
      using (var format = new StringFormat()) {
        format.Alignment = centered ? StringAlignment.Center : StringAlignment.Near;
        path.AddString(text, family, (int)FontStyle.Bold, pixels, at, format);
        using (var pen = new Pen(Color.Black, pixels / 7f)) {
          pen.LineJoin = LineJoin.Round;
          g.DrawPath(pen, path);
        }
        using (var brush = new SolidBrush(color)) g.FillPath(brush, path);
      }
    }
  }
}
'@

$Script = Get-Item $PSCommandPath
if (-not (Test-Path $Executable) -or (Get-Item $Executable).LastWriteTime -lt $Script.LastWriteTime) {
  New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
  Add-Type -TypeDefinition $Source -ReferencedAssemblies System.Windows.Forms, System.Drawing `
    -OutputAssembly $Executable -OutputType WindowsApplication
}

$Arguments = if ($Fullscreen) { @("--fullscreen") } else { @() }
$Process = if ($Arguments.Count -gt 0) {
  Start-Process -FilePath $Executable -ArgumentList $Arguments -PassThru
} else {
  Start-Process -FilePath $Executable -PassThru
}
if ($PassThru) { $Process }
