#!/usr/bin/env python3

"""
╔══════════════════════════════════════════════════════════════════════════╗
║                        NEXUS Rich Terminal Utilities                        ║
║                     Enhanced Terminal Experience with Rich                  ║
╚══════════════════════════════════════════════════════════════════════════╝
"""

import sys
import os
import json
import subprocess
from pathlib import Path
from typing import Optional, List, Dict, Any
import click
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.syntax import Syntax
from rich.markdown import Markdown
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn
from rich.tree import Tree
from rich.layout import Layout
from rich.live import Live
from rich.text import Text
from rich.prompt import Prompt, Confirm
from rich import print as rprint
from rich.traceback import install

# Install rich traceback handler
install(show_locals=True)

console = Console()

@click.group()
def cli():
    """NEXUS Rich Terminal Utilities - Enhanced CLI Experience"""
    pass

@cli.command()
@click.argument('path', type=click.Path(exists=True), default='.')
def tree(path):
    """Display directory tree with rich formatting"""
    path_obj = Path(path)

    tree = Tree(
        f"[bold cyan]{path_obj.absolute()}[/bold cyan]",
        guide_style="cyan"
    )

    def add_directory(tree_node, directory: Path, max_depth: int = 3, current_depth: int = 0):
        if current_depth >= max_depth:
            return

        try:
            paths = sorted(directory.iterdir())
        except PermissionError:
            tree_node.add("[red]Permission Denied[/red]")
            return

        for path in paths:
            if path.name.startswith('.'):
                continue

            if path.is_dir():
                branch = tree_node.add(
                    f"[bold blue]📁 {path.name}[/bold blue]"
                )
                add_directory(branch, path, max_depth, current_depth + 1)
            else:
                size = path.stat().st_size
                size_str = format_size(size)
                icon = get_file_icon(path.suffix)
                tree_node.add(
                    f"{icon} [green]{path.name}[/green] [dim]{size_str}[/dim]"
                )

    add_directory(tree, path_obj)
    console.print(tree)

@cli.command()
def sysinfo():
    """Display system information with rich formatting"""
    import platform
    import psutil
    import socket

    # Create layout
    layout = Layout()
    layout.split_column(
        Layout(name="header", size=3),
        Layout(name="body"),
        Layout(name="footer", size=3)
    )

    # Header
    header = Panel(
        Text("NEXUS System Information", style="bold cyan", justify="center"),
        style="cyan"
    )
    layout["header"].update(header)

    # System info table
    table = Table(title="System Details", show_header=True, header_style="bold magenta")
    table.add_column("Property", style="cyan", width=20)
    table.add_column("Value", style="green")

    # Add system information
    table.add_row("Hostname", socket.gethostname())
    table.add_row("Platform", platform.system())
    table.add_row("Release", platform.release())
    table.add_row("Architecture", platform.machine())
    table.add_row("Processor", platform.processor()[:50] + "...")
    table.add_row("Python Version", platform.python_version())

    # CPU info
    table.add_row("CPU Cores", f"{psutil.cpu_count(logical=False)} physical, {psutil.cpu_count()} logical")
    table.add_row("CPU Usage", f"{psutil.cpu_percent(interval=1)}%")

    # Memory info
    mem = psutil.virtual_memory()
    table.add_row("Total RAM", format_size(mem.total))
    table.add_row("Available RAM", format_size(mem.available))
    table.add_row("RAM Usage", f"{mem.percent}%")

    # Disk info
    disk = psutil.disk_usage('/')
    table.add_row("Disk Total", format_size(disk.total))
    table.add_row("Disk Free", format_size(disk.free))
    table.add_row("Disk Usage", f"{disk.percent}%")

    # Network info
    net = psutil.net_if_addrs()
    interfaces = ", ".join(net.keys())
    table.add_row("Network Interfaces", interfaces)

    layout["body"].update(table)

    # Footer
    footer = Panel(
        Text("🚀 NEXUS Hyprland Environment", style="bold blue", justify="center"),
        style="blue"
    )
    layout["footer"].update(footer)

    console.print(layout)

@cli.command()
@click.argument('file', type=click.Path(exists=True))
@click.option('--syntax', '-s', help='Force syntax highlighting language')
def view(file, syntax):
    """View file with syntax highlighting"""
    file_path = Path(file)

    if file_path.suffix in ['.md', '.markdown']:
        with open(file_path) as f:
            markdown = Markdown(f.read())
        console.print(markdown)
    elif file_path.suffix in ['.json']:
        with open(file_path) as f:
            data = json.load(f)
        console.print_json(data=data)
    else:
        with open(file_path) as f:
            content = f.read()

        if not syntax:
            syntax = get_syntax_from_extension(file_path.suffix)

        syntax_obj = Syntax(content, syntax or "text", theme="monokai", line_numbers=True)
        console.print(syntax_obj)

@cli.command()
def monitor():
    """Live system monitoring dashboard"""
    import time
    import psutil

    def generate_table():
        # CPU Usage
        cpu_percent = psutil.cpu_percent(interval=0.1, percpu=True)

        # Memory
        mem = psutil.virtual_memory()

        # Create main table
        table = Table(title="🚀 NEXUS System Monitor", show_header=True, header_style="bold cyan")
        table.add_column("Metric", style="cyan", width=20)
        table.add_column("Value", style="green", width=30)
        table.add_column("Visual", width=40)

        # CPU bars
        cpu_avg = sum(cpu_percent) / len(cpu_percent)
        cpu_bar = create_bar(cpu_avg, 100, 30)
        table.add_row("CPU Average", f"{cpu_avg:.1f}%", cpu_bar)

        for i, percent in enumerate(cpu_percent):
            bar = create_bar(percent, 100, 30)
            table.add_row(f"  Core {i}", f"{percent:.1f}%", bar)

        # Memory
        mem_bar = create_bar(mem.percent, 100, 30)
        table.add_row("Memory", f"{format_size(mem.used)}/{format_size(mem.total)} ({mem.percent:.1f}%)", mem_bar)

        # Disk
        disk = psutil.disk_usage('/')
        disk_bar = create_bar(disk.percent, 100, 30)
        table.add_row("Disk /", f"{format_size(disk.used)}/{format_size(disk.total)} ({disk.percent:.1f}%)", disk_bar)

        # Network
        net_io = psutil.net_io_counters()
        table.add_row("Network ↓", f"{format_size(net_io.bytes_recv)}", "")
        table.add_row("Network ↑", f"{format_size(net_io.bytes_sent)}", "")

        # Processes
        procs = len(psutil.pids())
        table.add_row("Processes", str(procs), "")

        # Temperature (if available)
        try:
            temps = psutil.sensors_temperatures()
            if temps:
                for name, entries in temps.items():
                    for entry in entries[:1]:  # Just first sensor
                        temp_bar = create_bar(entry.current, entry.high or 100, 30)
                        table.add_row(f"Temp {name}", f"{entry.current:.1f}°C", temp_bar)
        except:
            pass

        return table

    with Live(generate_table(), refresh_per_second=2, console=console) as live:
        try:
            while True:
                time.sleep(0.5)
                live.update(generate_table())
        except KeyboardInterrupt:
            pass

@cli.command()
@click.argument('commands', nargs=-1, required=True)
def run(commands):
    """Run commands with rich progress display"""
    commands = list(commands)

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
        console=console
    ) as progress:

        task = progress.add_task("[cyan]Running commands...", total=len(commands))

        for cmd in commands:
            progress.update(task, description=f"[yellow]Running: {cmd}")

            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

            if result.returncode == 0:
                console.print(f"[green]✓[/green] {cmd}")
                if result.stdout:
                    console.print(Panel(result.stdout, title="Output", style="green"))
            else:
                console.print(f"[red]✗[/red] {cmd}")
                if result.stderr:
                    console.print(Panel(result.stderr, title="Error", style="red"))

            progress.advance(task)

@cli.command()
def colors():
    """Display color palette"""
    colors = {
        "NEXUS Theme": {
            "Neon Purple": "#b967ff",
            "Neon Cyan": "#01cdfe",
            "Electric Blue": "#05ffa1",
            "Deep Purple": "#2d1b69",
            "Dark Background": "#0d0221",
            "Warning Red": "#ff2a6d"
        },
        "Standard Colors": {
            "Black": "black",
            "Red": "red",
            "Green": "green",
            "Yellow": "yellow",
            "Blue": "blue",
            "Magenta": "magenta",
            "Cyan": "cyan",
            "White": "white"
        }
    }

    for theme_name, theme_colors in colors.items():
        console.print(f"\n[bold]{theme_name}[/bold]")

        table = Table(show_header=False, box=None)
        table.add_column("Color", width=20)
        table.add_column("Sample", width=30)
        table.add_column("Hex", width=15)

        for name, color in theme_colors.items():
            sample = f"[{color}]████████████████████████[/{color}]"
            table.add_row(name, sample, color)

        console.print(table)

# Utility functions
def format_size(bytes: int) -> str:
    """Format bytes to human readable size"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes < 1024.0:
            return f"{bytes:.1f} {unit}"
        bytes /= 1024.0
    return f"{bytes:.1f} PB"

def get_file_icon(extension: str) -> str:
    """Get icon for file type"""
    icons = {
        '.py': '🐍',
        '.js': '📜',
        '.ts': '📘',
        '.json': '📋',
        '.md': '📝',
        '.txt': '📄',
        '.sh': '🔧',
        '.yml': '⚙️',
        '.yaml': '⚙️',
        '.toml': '⚙️',
        '.conf': '⚙️',
        '.jpg': '🖼️',
        '.png': '🖼️',
        '.gif': '🖼️',
        '.mp4': '🎬',
        '.mp3': '🎵',
        '.zip': '📦',
        '.tar': '📦',
        '.gz': '📦',
    }
    return icons.get(extension.lower(), '📄')

def get_syntax_from_extension(extension: str) -> Optional[str]:
    """Get syntax highlighting language from file extension"""
    syntax_map = {
        '.py': 'python',
        '.js': 'javascript',
        '.ts': 'typescript',
        '.sh': 'bash',
        '.yml': 'yaml',
        '.yaml': 'yaml',
        '.json': 'json',
        '.toml': 'toml',
        '.rs': 'rust',
        '.go': 'go',
        '.c': 'c',
        '.cpp': 'cpp',
        '.h': 'c',
        '.hpp': 'cpp',
        '.java': 'java',
        '.rb': 'ruby',
        '.php': 'php',
        '.html': 'html',
        '.css': 'css',
        '.sql': 'sql',
    }
    return syntax_map.get(extension.lower())

def create_bar(value: float, max_value: float, width: int) -> str:
    """Create a progress bar"""
    filled = int((value / max_value) * width)
    bar = '█' * filled + '░' * (width - filled)

    if value > 80:
        color = "red"
    elif value > 60:
        color = "yellow"
    else:
        color = "green"

    return f"[{color}]{bar}[/{color}]"

if __name__ == '__main__':
    cli()